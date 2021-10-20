// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This file is auto-generated.

#include "sw/device/lib/dif/autogen/dif_rv_timer_autogen.h"

#include "gtest/gtest.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/base/testing/mock_mmio.h"

#include "rv_timer_regs.h"  // Generated.

namespace dif_rv_timer_autogen_unittest {
namespace {
using ::mock_mmio::MmioTest;
using ::mock_mmio::MockDevice;
using ::testing::Test;

class RvTimerTest : public Test, public MmioTest {
 protected:
  dif_rv_timer_t rv_timer_ = {.base_addr = dev().region()};
};

using ::testing::Eq;

class IrqGetStateTest : public RvTimerTest {};

TEST_F(IrqGetStateTest, NullArgs) {
  dif_rv_timer_irq_state_snapshot_t irq_snapshot = 0;

  EXPECT_EQ(dif_rv_timer_irq_get_state(nullptr, 0, &irq_snapshot), kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_get_state(&rv_timer_, 0, nullptr), kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_get_state(nullptr, 0, nullptr), kDifBadArg);
}

TEST_F(IrqGetStateTest, SuccessAllRaised) {
  dif_rv_timer_irq_state_snapshot_t irq_snapshot = 0;

  EXPECT_READ32(RV_TIMER_INTR_STATE0_REG_OFFSET,
                std::numeric_limits<uint32_t>::max());
  EXPECT_EQ(dif_rv_timer_irq_get_state(&rv_timer_, 0, &irq_snapshot), kDifOk);
  EXPECT_EQ(irq_snapshot, std::numeric_limits<uint32_t>::max());
}

TEST_F(IrqGetStateTest, SuccessNoneRaised) {
  dif_rv_timer_irq_state_snapshot_t irq_snapshot = 0;

  EXPECT_READ32(RV_TIMER_INTR_STATE0_REG_OFFSET, 0);
  EXPECT_EQ(dif_rv_timer_irq_get_state(&rv_timer_, 0, &irq_snapshot), kDifOk);
  EXPECT_EQ(irq_snapshot, 0);
}

class IrqIsPendingTest : public RvTimerTest {};

TEST_F(IrqIsPendingTest, NullArgs) {
  bool is_pending;

  EXPECT_EQ(dif_rv_timer_irq_is_pending(
                nullptr, kDifRvTimerIrqTimerExpiredHart0Timer0, &is_pending),
            kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_is_pending(
                &rv_timer_, kDifRvTimerIrqTimerExpiredHart0Timer0, nullptr),
            kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_is_pending(
                nullptr, kDifRvTimerIrqTimerExpiredHart0Timer0, nullptr),
            kDifBadArg);
}

TEST_F(IrqIsPendingTest, BadIrq) {
  bool is_pending;
  // All interrupt CSRs are 32 bit so interrupt 32 will be invalid.
  EXPECT_EQ(dif_rv_timer_irq_is_pending(
                &rv_timer_, static_cast<dif_rv_timer_irq_t>(32), &is_pending),
            kDifBadArg);
}

TEST_F(IrqIsPendingTest, Success) {
  bool irq_state;

  // Get the first IRQ state.
  irq_state = false;
  EXPECT_READ32(RV_TIMER_INTR_STATE0_REG_OFFSET, {{0, true}});
  EXPECT_EQ(dif_rv_timer_irq_is_pending(
                &rv_timer_, kDifRvTimerIrqTimerExpiredHart0Timer0, &irq_state),
            kDifOk);
  EXPECT_TRUE(irq_state);
}

class IrqAcknowledgeTest : public RvTimerTest {};

TEST_F(IrqAcknowledgeTest, NullArgs) {
  EXPECT_EQ(dif_rv_timer_irq_acknowledge(nullptr,
                                         kDifRvTimerIrqTimerExpiredHart0Timer0),
            kDifBadArg);
}

TEST_F(IrqAcknowledgeTest, BadIrq) {
  EXPECT_EQ(dif_rv_timer_irq_acknowledge(nullptr,
                                         static_cast<dif_rv_timer_irq_t>(32)),
            kDifBadArg);
}

TEST_F(IrqAcknowledgeTest, Success) {
  // Clear the first IRQ state.
  EXPECT_WRITE32(RV_TIMER_INTR_STATE0_REG_OFFSET, {{0, true}});
  EXPECT_EQ(dif_rv_timer_irq_acknowledge(&rv_timer_,
                                         kDifRvTimerIrqTimerExpiredHart0Timer0),
            kDifOk);
}

class IrqForceTest : public RvTimerTest {};

TEST_F(IrqForceTest, NullArgs) {
  EXPECT_EQ(
      dif_rv_timer_irq_force(nullptr, kDifRvTimerIrqTimerExpiredHart0Timer0),
      kDifBadArg);
}

TEST_F(IrqForceTest, BadIrq) {
  EXPECT_EQ(
      dif_rv_timer_irq_force(nullptr, static_cast<dif_rv_timer_irq_t>(32)),
      kDifBadArg);
}

TEST_F(IrqForceTest, Success) {
  // Force first IRQ.
  EXPECT_WRITE32(RV_TIMER_INTR_TEST0_REG_OFFSET, {{0, true}});
  EXPECT_EQ(
      dif_rv_timer_irq_force(&rv_timer_, kDifRvTimerIrqTimerExpiredHart0Timer0),
      kDifOk);
}

class IrqGetEnabledTest : public RvTimerTest {};

TEST_F(IrqGetEnabledTest, NullArgs) {
  dif_toggle_t irq_state;

  EXPECT_EQ(dif_rv_timer_irq_get_enabled(
                nullptr, kDifRvTimerIrqTimerExpiredHart0Timer0, &irq_state),
            kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_get_enabled(
                &rv_timer_, kDifRvTimerIrqTimerExpiredHart0Timer0, nullptr),
            kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_get_enabled(
                nullptr, kDifRvTimerIrqTimerExpiredHart0Timer0, nullptr),
            kDifBadArg);
}

TEST_F(IrqGetEnabledTest, BadIrq) {
  dif_toggle_t irq_state;

  EXPECT_EQ(dif_rv_timer_irq_get_enabled(
                &rv_timer_, static_cast<dif_rv_timer_irq_t>(32), &irq_state),
            kDifBadArg);
}

TEST_F(IrqGetEnabledTest, Success) {
  dif_toggle_t irq_state;

  // First IRQ is enabled.
  irq_state = kDifToggleDisabled;
  EXPECT_READ32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, {{0, true}});
  EXPECT_EQ(dif_rv_timer_irq_get_enabled(
                &rv_timer_, kDifRvTimerIrqTimerExpiredHart0Timer0, &irq_state),
            kDifOk);
  EXPECT_EQ(irq_state, kDifToggleEnabled);
}

class IrqSetEnabledTest : public RvTimerTest {};

TEST_F(IrqSetEnabledTest, NullArgs) {
  dif_toggle_t irq_state = kDifToggleEnabled;

  EXPECT_EQ(dif_rv_timer_irq_set_enabled(
                nullptr, kDifRvTimerIrqTimerExpiredHart0Timer0, irq_state),
            kDifBadArg);
}

TEST_F(IrqSetEnabledTest, BadIrq) {
  dif_toggle_t irq_state = kDifToggleEnabled;

  EXPECT_EQ(dif_rv_timer_irq_set_enabled(
                &rv_timer_, static_cast<dif_rv_timer_irq_t>(32), irq_state),
            kDifBadArg);
}

TEST_F(IrqSetEnabledTest, Success) {
  dif_toggle_t irq_state;

  // Enable first IRQ.
  irq_state = kDifToggleEnabled;
  EXPECT_MASK32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, {{0, 0x1, true}});
  EXPECT_EQ(dif_rv_timer_irq_set_enabled(
                &rv_timer_, kDifRvTimerIrqTimerExpiredHart0Timer0, irq_state),
            kDifOk);
}

class IrqDisableAllTest : public RvTimerTest {};

TEST_F(IrqDisableAllTest, NullArgs) {
  dif_rv_timer_irq_enable_snapshot_t irq_snapshot = 0;

  EXPECT_EQ(dif_rv_timer_irq_disable_all(nullptr, 0, &irq_snapshot),
            kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_disable_all(nullptr, 0, nullptr), kDifBadArg);
}

TEST_F(IrqDisableAllTest, SuccessNoSnapshot) {
  EXPECT_WRITE32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, 0);
  EXPECT_EQ(dif_rv_timer_irq_disable_all(&rv_timer_, 0, nullptr), kDifOk);
}

TEST_F(IrqDisableAllTest, SuccessSnapshotAllDisabled) {
  dif_rv_timer_irq_enable_snapshot_t irq_snapshot = 0;

  EXPECT_READ32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, 0);
  EXPECT_WRITE32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, 0);
  EXPECT_EQ(dif_rv_timer_irq_disable_all(&rv_timer_, 0, &irq_snapshot), kDifOk);
  EXPECT_EQ(irq_snapshot, 0);
}

TEST_F(IrqDisableAllTest, SuccessSnapshotAllEnabled) {
  dif_rv_timer_irq_enable_snapshot_t irq_snapshot = 0;

  EXPECT_READ32(RV_TIMER_INTR_ENABLE0_REG_OFFSET,
                std::numeric_limits<uint32_t>::max());
  EXPECT_WRITE32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, 0);
  EXPECT_EQ(dif_rv_timer_irq_disable_all(&rv_timer_, 0, &irq_snapshot), kDifOk);
  EXPECT_EQ(irq_snapshot, std::numeric_limits<uint32_t>::max());
}

class IrqRestoreAllTest : public RvTimerTest {};

TEST_F(IrqRestoreAllTest, NullArgs) {
  dif_rv_timer_irq_enable_snapshot_t irq_snapshot = 0;

  EXPECT_EQ(dif_rv_timer_irq_restore_all(nullptr, 0, &irq_snapshot),
            kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_restore_all(&rv_timer_, 0, nullptr), kDifBadArg);

  EXPECT_EQ(dif_rv_timer_irq_restore_all(nullptr, 0, nullptr), kDifBadArg);
}

TEST_F(IrqRestoreAllTest, SuccessAllEnabled) {
  dif_rv_timer_irq_enable_snapshot_t irq_snapshot =
      std::numeric_limits<uint32_t>::max();

  EXPECT_WRITE32(RV_TIMER_INTR_ENABLE0_REG_OFFSET,
                 std::numeric_limits<uint32_t>::max());
  EXPECT_EQ(dif_rv_timer_irq_restore_all(&rv_timer_, 0, &irq_snapshot), kDifOk);
}

TEST_F(IrqRestoreAllTest, SuccessAllDisabled) {
  dif_rv_timer_irq_enable_snapshot_t irq_snapshot = 0;

  EXPECT_WRITE32(RV_TIMER_INTR_ENABLE0_REG_OFFSET, 0);
  EXPECT_EQ(dif_rv_timer_irq_restore_all(&rv_timer_, 0, &irq_snapshot), kDifOk);
}

}  // namespace
}  // namespace dif_rv_timer_autogen_unittest