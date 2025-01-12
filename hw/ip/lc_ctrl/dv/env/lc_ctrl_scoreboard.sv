// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class lc_ctrl_scoreboard extends cip_base_scoreboard #(
  .CFG_T(lc_ctrl_env_cfg),
  .RAL_T(lc_ctrl_reg_block),
  .COV_T(lc_ctrl_env_cov)
);
  `uvm_component_utils(lc_ctrl_scoreboard)

  // local variables
  bit is_personalized = 0;

  // Data to program OTP
  protected otp_ctrl_pkg::lc_otp_program_req_t m_otp_prog_data;
  // First OTP program instruction count cleared by reset
  protected uint m_otp_prog_cnt;
  event check_lc_output_ev;

  // TLM agent fifos
  uvm_tlm_analysis_fifo #(push_pull_item #(
    .HostDataWidth  (OTP_PROG_HDATA_WIDTH),
    .DeviceDataWidth(OTP_PROG_DDATA_WIDTH)
  )) otp_prog_fifo;
  uvm_tlm_analysis_fifo #(push_pull_item #(
    .HostDataWidth(lc_ctrl_state_pkg::LcTokenWidth)
  )) otp_token_fifo;
  uvm_tlm_analysis_fifo #(alert_esc_seq_item) esc_wipe_secrets_fifo;
  uvm_tlm_analysis_fifo #(alert_esc_seq_item) esc_scrap_state_fifo;
  uvm_tlm_analysis_fifo #(jtag_riscv_item) jtag_riscv_fifo;

  // local queues to hold incoming packets pending comparison

  `uvm_component_new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    otp_prog_fifo = new("otp_prog_fifo", this);
    otp_token_fifo = new("otp_token_fifo", this);
    esc_wipe_secrets_fifo = new("esc_wipe_secrets_fifo", this);
    esc_scrap_state_fifo = new("esc_scrap_state_fifo", this);
    jtag_riscv_fifo = new("jtag_riscv_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork
      check_lc_output();
      process_otp_prog_rsp();
      process_otp_token_rsp();
      process_jtag_riscv();
    join_none
  endtask

  virtual task check_lc_output();
    forever begin
      @(posedge cfg.pwr_lc_vif.pins[LcPwrDoneRsp] && cfg.en_scb) begin
        // TODO: add coverage
        dec_lc_state_e lc_state = dec_lc_state(cfg.lc_ctrl_vif.otp_i.state);
        lc_outputs_t   exp_lc_o = EXP_LC_OUTPUTS[int'(lc_state)];
        string         err_msg = $sformatf("LC_St %0s", lc_state.name);
        cfg.clk_rst_vif.wait_n_clks(1);

        // lc_creator_seed_sw_rw_en_o is ON only when device has NOT been personalized or RMA state
        if (is_personalized && lc_state != DecLcStRma) begin
          exp_lc_o.lc_creator_seed_sw_rw_en_o = lc_ctrl_pkg::Off;
        end
        // lc_seed_hw_rd_en_o is ON only when device has been personalized or RMA state
        if (!is_personalized && lc_state != DecLcStRma) begin
          exp_lc_o.lc_seed_hw_rd_en_o = lc_ctrl_pkg::Off;
        end

        ->check_lc_output_ev;
        check_lc_outputs(exp_lc_o, err_msg);


        if (cfg.err_inj.state_err || cfg.err_inj.count_err ||
            cfg.err_inj.state_backdoor_err || cfg.err_inj.count_backdoor_err
            ) begin // State/count error expected
          set_exp_alert(.alert_name("fatal_state_error"), .is_fatal(1),
                        .max_delay(cfg.alert_max_delay));
        end

      end
    end
  endtask

  virtual task process_otp_prog_rsp();
    otp_ctrl_pkg::lc_otp_program_req_t otp_prog_data_exp;
    lc_state_e otp_prog_state_act, otp_prog_state_exp;
    lc_cnt_e otp_prog_count_act, otp_prog_count_exp;
    const string MsgFmt = "Check failed %s == %s %s [%h] vs %s [%h]";
    forever begin
      push_pull_item #(
        .HostDataWidth  (OTP_PROG_HDATA_WIDTH),
        .DeviceDataWidth(OTP_PROG_DDATA_WIDTH)
      ) item_rcv;
      otp_prog_fifo.get(item_rcv);
      if (item_rcv.d_data == 1 && cfg.en_scb) begin
        set_exp_alert(.alert_name("fatal_prog_error"), .is_fatal(1));
      end
      // Decode and store to use for prediction
      m_otp_prog_data = otp_ctrl_pkg::lc_otp_program_req_t'(item_rcv.h_data);

      // Increment otp program count
      m_otp_prog_cnt++;

      // Get expected from model
      otp_prog_data_exp  = predict_otp_prog_req();

      otp_prog_state_act = lc_state_e'(m_otp_prog_data.state);
      otp_prog_state_exp = lc_state_e'(otp_prog_data_exp.state);
      otp_prog_count_exp = lc_cnt_e'(otp_prog_data_exp.count);
      otp_prog_count_act = lc_cnt_e'(m_otp_prog_data.count);

      `DV_CHECK_EQ(otp_prog_state_act, otp_prog_state_exp, $sformatf(
                   " - %s vs %s", otp_prog_state_act.name, otp_prog_state_exp.name))

      `DV_CHECK_EQ(otp_prog_count_act, otp_prog_count_exp, $sformatf(
                   " - %s vs %s", otp_prog_count_act.name, otp_prog_count_exp.name))
    end
  endtask

  // verilog_format: off - avoid bad formatting
  virtual task process_otp_token_rsp();
    forever begin
      push_pull_item#(.HostDataWidth(lc_ctrl_state_pkg::LcTokenWidth)) item_rcv;
      otp_token_fifo.get(item_rcv);
      if (cfg.en_scb) begin
        `DV_CHECK_EQ(item_rcv.h_data, {`gmv(ral.transition_token[3]),
                                       `gmv(ral.transition_token[2]),
                                       `gmv(ral.transition_token[1]),
                                       `gmv(ral.transition_token[0])})
      end
    end
  endtask
  // verilog_format: on

  virtual task process_jtag_riscv();
    jtag_riscv_item      jt_item;
    tl_seq_item          tl_item;
    const uvm_reg_addr_t jtag_risc_address_mask = ~(2 ** (DMI_ADDRW + 2) - 1);
    const uvm_reg_addr_t base_address = cfg.jtag_riscv_map.get_base_addr();
    const uvm_reg_addr_t base_address_masked = base_address & jtag_risc_address_mask;

    forever begin
      jtag_riscv_fifo.get(jt_item);
      `uvm_info(`gfn, {"process_jtag_risc: ", jt_item.sprint(uvm_default_line_printer)}, UVM_MEDIUM)
      if ((jt_item.op === DmiRead || jt_item.op === DmiWrite) && jt_item.status === DmiNoErr) begin
        `uvm_create_obj(tl_seq_item, tl_item)
        tl_item.a_addr   = base_address_masked | (jt_item.addr << 2);
        tl_item.a_data   = jt_item.data;
        tl_item.a_opcode = (jt_item.op === DmiRead) ? tlul_pkg::Get : tlul_pkg::PutFullData;
        tl_item.a_mask   = '1;
        tl_item.d_data   = jt_item.data;
        tl_item.d_opcode = (jt_item.op === DmiRead) ? tlul_pkg::Get : tlul_pkg::PutFullData;


        process_tl_access(tl_item, AddrChannel, "lc_ctrl_reg_block");
        process_tl_access(tl_item, DataChannel, "lc_ctrl_reg_block");


      end
    end
  endtask

  // check lc outputs, default all off
  virtual function void check_lc_outputs(lc_outputs_t exp_o = '{default: lc_ctrl_pkg::Off},
                                         string msg = "expect all output OFF");
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_dft_en_o, exp_o.lc_dft_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_nvm_debug_en_o, exp_o.lc_nvm_debug_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_hw_debug_en_o, exp_o.lc_hw_debug_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_cpu_en_o, exp_o.lc_cpu_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_keymgr_en_o, exp_o.lc_keymgr_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_escalate_en_o, exp_o.lc_escalate_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_owner_seed_sw_rw_en_o, exp_o.lc_owner_seed_sw_rw_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_iso_part_sw_rd_en_o, exp_o.lc_iso_part_sw_rd_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_iso_part_sw_wr_en_o, exp_o.lc_iso_part_sw_wr_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_seed_hw_rd_en_o, exp_o.lc_seed_hw_rd_en_o, msg)
    `DV_CHECK_EQ(cfg.lc_ctrl_vif.lc_creator_seed_sw_rw_en_o, exp_o.lc_creator_seed_sw_rw_en_o, msg)
  endfunction

  virtual task process_tl_access(tl_seq_item item, tl_channels_e channel, string ral_name);
    uvm_reg        csr;
    bit            do_read_check = 1'b0;
    bit            write = item.is_write();
    uvm_reg_addr_t csr_addr = cfg.ral_models[ral_name].get_word_aligned_addr(item.a_addr);
    lc_outputs_t   exp = '{default: lc_ctrl_pkg::Off};

    bit            addr_phase_read = (!write && channel == AddrChannel);
    bit            addr_phase_write = (write && channel == AddrChannel);
    bit            data_phase_read = (!write && channel == DataChannel);
    bit            data_phase_write = (write && channel == DataChannel);

    // if access was to a valid csr, get the csr handle
    if (csr_addr inside {cfg.ral_models[ral_name].csr_addrs}) begin
      csr = cfg.ral_models[ral_name].default_map.get_reg_by_offset(csr_addr);
      `DV_CHECK_NE_FATAL(csr, null)
    end else begin
      `uvm_fatal(`gfn, $sformatf("Access unexpected addr 0x%0h", csr_addr))
    end

    // if incoming access is a write to a valid csr, then make updates right away
    if (addr_phase_write) begin
      `uvm_info(`gfn, {
                "process_tl_access: write predict ",
                csr.get_name(),
                " ",
                item.sprint(uvm_default_line_printer)
                }, UVM_MEDIUM)
      void'(csr.predict(.value(item.a_data), .kind(UVM_PREDICT_WRITE), .be(item.a_mask)));
    end

    if (addr_phase_read) begin
      case (csr.get_name())
        "lc_state": begin
          // if (cfg.err_inj.state_err) begin // State error expected
          //   case(cfg.test_phase)
          //     LcCtrlReadState1: `DV_CHECK_FATAL(
          //         ral.lc_state.predict(.value(DecLcStInvalid), .kind(UVM_PREDICT_READ)))
          //     LcCtrlReadState2: `DV_CHECK_FATAL(
          //         ral.lc_state.predict(.value(DecLcStEscalate), .kind(UVM_PREDICT_READ)))
          //   endcase
          `DV_CHECK_FATAL(ral.lc_state.state.predict(
                          .value(predict_lc_state()), .kind(UVM_PREDICT_READ)))
        end

        "lc_transition_cnt": begin
          // If we have a state error no transition will take place so
          // the tarnsition count will be 31
          if(!cfg.err_inj.count_err && !cfg.err_inj.state_err &&
              !cfg.err_inj.count_backdoor_err && !cfg.err_inj.state_backdoor_err
              ) begin
            `DV_CHECK_FATAL((ral.lc_transition_cnt.predict(
                            .value(dec_lc_cnt(cfg.lc_ctrl_vif.otp_i.count)), .kind(UVM_PREDICT_READ)
                            )))
          end else begin  // State or count error expected
            `DV_CHECK_FATAL(ral.lc_transition_cnt.predict(.value(31), .kind(UVM_PREDICT_READ)))
          end
        end

        default: begin
          // `uvm_fatal(`gfn, $sformatf("invalid csr: %0s", csr.get_full_name()))
        end
      endcase
    end

    // On reads, if do_read_check, is set, then check mirrored_value against item.d_data
    if (data_phase_read) begin
      if (csr.get_name() inside {"lc_state", "lc_transition_cnt"}) do_read_check = 1;

      if (do_read_check) begin
        `DV_CHECK_EQ(csr.get_mirrored_value(), item.d_data, $sformatf(
                     "reg name: %0s", csr.get_full_name()))
      end
      void'(csr.predict(.value(item.d_data), .kind(UVM_PREDICT_READ)));
      `uvm_info(`gfn, {
                "process_tl_access: read predict ",
                csr.get_name(),
                " ",
                item.sprint(uvm_default_line_printer)
                }, UVM_MEDIUM)

      // when lc successfully req a transition, all outputs are turned off.
      if (cfg.err_inj.state_backdoor_err || cfg.err_inj.count_backdoor_err) begin
        // Expect escalate
        exp.lc_escalate_en_o = lc_ctrl_pkg::On;
      end

      if (ral.status.transition_successful.get()) check_lc_outputs(exp);
    end
  endtask

  // Predict the value of lc_state register
  virtual function bit [31:0] predict_lc_state();
    // Unrepeated lc_state expected - default state from otp_i
    dec_lc_state_e lc_state_single_exp = dec_lc_state(cfg.lc_ctrl_vif.otp_i.state);
    bit [31:0] lc_state_exp;

    // Exceptions to default
    if (cfg.err_inj.state_err || cfg.err_inj.count_err || cfg.err_inj.count_backdoor_err ||
        cfg.err_inj.state_backdoor_err) begin // State error expected
      case (cfg.test_phase)
        LcCtrlReadState1: lc_state_single_exp = DecLcStInvalid;
        LcCtrlReadState2: lc_state_single_exp = DecLcStEscalate;
        default: lc_state_single_exp = DecLcStInvalid;
      endcase
    end
    // repeat state to fill the word for hardness
    lc_state_exp = {DecLcStateNumRep{lc_state_single_exp}};

    `uvm_info(`gfn, $sformatf(
              "predict_lc_state: lc_state_single_exp=%s(%x) lc_state_exp=%h",
              lc_state_single_exp.name,
              lc_state_single_exp,
              lc_state_exp
              ), UVM_MEDIUM)

    return lc_state_exp;
  endfunction

  virtual function otp_ctrl_pkg::lc_otp_program_req_t predict_otp_prog_req();
    // Convert state and count back to enums
    const lc_state_e LcStateIn = cfg.lc_ctrl_vif.otp_i.state;
    const lc_cnt_e LcCntIn = cfg.lc_ctrl_vif.otp_i.count;
    // Incremented LcCntIn - next() works because of encoding method
    const lc_cnt_e LcCntInInc = LcCntIn.next();
    // TODO needs expanding for JTAG registers
    const
    lc_state_e
    LcTargetState = encode_lc_state(
        cfg.ral.transition_target.get_mirrored_value()
    );
    lc_state_e lc_state_exp;
    lc_cnt_e lc_cnt_exp;

    if (m_otp_prog_cnt == 1) begin
      // First program transaction just programs the incremented count so state
      // is the same as input
      lc_cnt_exp   = LcCntInInc;
      lc_state_exp = LcStateIn;
    end else if (m_otp_prog_cnt == 2) begin
      // Second program transaction programs both the incremented count and
      // the transition target state in (TRANSITION_TARGET register)
      lc_cnt_exp   = LcCntInInc;
      lc_state_exp = LcTargetState;
    end

    // Transition to SCRAP state always programs LcCnt24
    if (LcTargetState == LcStScrap) lc_cnt_exp = LcCnt24;

    `uvm_info(`gfn, $sformatf(
              "predict_otp_prog_req: state=%s count=%s", lc_state_exp.name(), lc_cnt_exp.name),
              UVM_MEDIUM)

    return ('{state: lc_state_t'(lc_state_exp), count: lc_cnt_t'(lc_cnt_exp), req: 0});
  endfunction

  // this function check if the triggered alert is expected
  // to turn off this check, user can set `do_alert_check` to 0
  // We overload this to trigger events in the config object when an alert is triggered
  virtual function void process_alert(string alert_name, alert_esc_seq_item item);
    if (item.alert_handshake_sta == AlertReceived) begin
      case (alert_name)
        "fatal_prog_error": begin
          ->cfg.fatal_prog_error_ev;
        end
        "fatal_state_error": begin
          ->cfg.fatal_state_error_ev;
        end
        "fatal_bus_integ_error": begin
          ->cfg.fatal_bus_integ_error_ev;
        end
        default: begin
          `uvm_fatal(`gfn, {"Unexpected alert received: ", alert_name})
        end
      endcase
    end

    super.process_alert(alert_name, item);

  endfunction

  virtual function void reset(string kind = "HARD");
    super.reset(kind);
    // reset local fifos queues and variables
    // Clear OTP program count
    m_otp_prog_cnt = 0;
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    // post test checks - ensure that all local fifos and queues are empty
  endfunction

endclass
