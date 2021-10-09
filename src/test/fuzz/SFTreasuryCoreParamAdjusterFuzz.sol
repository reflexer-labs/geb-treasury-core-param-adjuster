pragma solidity 0.6.7;

import { DSTest } from "../../../lib/geb-treasuries/lib/geb/lib/ds-token/lib/ds-test/src/test.sol";
import { CoreStabilityFeeTreasury } from "../../../lib/geb-treasuries/src/CoreStabilityFeeTreasury.sol";
import "./SFTreasuryCoreParamAdjusterMock.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract SystemCoinMock {
    function approve(address,uint) public returns (bool) {
        return true;
    }
}

contract CoinJoinMock {
    address public systemCoin;
    constructor() public {
        systemCoin = address(new SystemCoinMock());
    }
}

contract Fuzz is SFTreasuryCoreParamAdjusterMock {

    constructor() public SFTreasuryCoreParamAdjusterMock(
        address(new CoreStabilityFeeTreasury(address(0x1), address(0x1), address(new CoinJoinMock()))),
        1 hours,    // updateDelay_
        now,    // lastUpdateTime_
        100,        // treasuryCapacityMultiplier_
        1000 ether, // minTreasuryCapacity_
        100,        // minimumFundsMultiplier_
        1 ether,    // minMinimumFunds_
        100,        // pullFundsMinThresholdMultiplier_
        2 ether     // minPullFundsThreshold_
    ) {
        authorizedAccounts[address(this)] = 1;
        rewardAdjusters[address(this)] = 1;
        rewardAdjusters[address(0x10000)] = 1;
        rewardAdjusters[address(0x20000)] = 1;
        rewardAdjusters[address(0xabc00)] = 1;

        // adding a funded function for the helper below
        whitelistedFundedFunctions[address(0x2)][bytes4("0x2")].latestExpectedCalls = 1;

        // set params to minimum
        treasury.modifyParameters("treasuryCapacity", minTreasuryCapacity);
        treasury.modifyParameters("minimumFundsRequired", minMinimumFunds);
        treasury.modifyParameters("pullFundsMinThreshold", minPullFundsThreshold);
    }

    function helper_maximum(uint a, uint b) internal pure returns (uint) {
        return (a > b) ? a : b;
    }

    // guided fuzz functions, will perform operations
    function fuzz_adjust_max_reward(uint maxReward) public {
        uint prevDynamicRawTreasuryCapacity = dynamicRawTreasuryCapacity;
        uint prevMaxRewards = whitelistedFundedFunctions[address(0x2)][bytes4("0x2")].latestMaxReward;
        SFTreasuryCoreParamAdjusterMock(address(this)).adjustMaxReward(address(0x2), bytes4("0x2"), maxReward);
        assert(whitelistedFundedFunctions[address(0x2)][bytes4("0x2")].latestMaxReward == maxReward);
        assert(dynamicRawTreasuryCapacity == prevDynamicRawTreasuryCapacity + maxReward - prevMaxRewards); // fundedFunction.latestExpectedCalls * newMaxReward
    }

    function fuzz_adjust_treasury_params() public {
        SFTreasuryCoreParamAdjusterMock(address(this)).setNewTreasuryParameters();
        assert(lastUpdateTime == now);

        uint newMaxTreasuryCapacity = (treasuryCapacityMultiplier * dynamicRawTreasuryCapacity / 100) * 10**27;

        assert(CoreStabilityFeeTreasury(address(treasury)).treasuryCapacity() == helper_maximum(minTreasuryCapacity, newMaxTreasuryCapacity));
    }

    // Properties

    function echidna_treasuryCapacity() public returns (bool) {
        return CoreStabilityFeeTreasury(address(treasury)).treasuryCapacity() >= minTreasuryCapacity;
    }

    function echidna_minimumFundsRequired() public returns (bool) {
        return CoreStabilityFeeTreasury(address(treasury)).minimumFundsRequired() >= minMinimumFunds;
    }

    function echidna_pullFundsMinThreshold() public returns (bool) {
        return CoreStabilityFeeTreasury(address(treasury)).pullFundsMinThreshold() >= minPullFundsThreshold;
    }
}

contract FuzzTest is Fuzz, DSTest {
    Hevm hevm;
    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);
    }

    function test_fuzz_setup() public {
        hevm.warp(now + updateDelay + 1);
        this.setNewTreasuryParameters();

        assertEq(lastUpdateTime, now);

        assertEq(CoreStabilityFeeTreasury(address(treasury)).treasuryCapacity(), minTreasuryCapacity);
        assertEq(CoreStabilityFeeTreasury(address(treasury)).minimumFundsRequired(), minTreasuryCapacity);
        assertEq(CoreStabilityFeeTreasury(address(treasury)).pullFundsMinThreshold(), minTreasuryCapacity);
    }


}