pragma solidity 0.6.7;

import "ds-test/test.sol";
import { CoreStabilityFeeTreasury } from "geb-treasuries/CoreStabilityFeeTreasury.sol";
import {Coin} from 'geb/Coin.sol';
import "geb/SAFEEngine.sol";
import {CoinJoin} from 'geb/BasicTokenAdapters.sol';
import { SFTreasuryCoreParamAdjuster } from "../SFTreasuryCoreParamAdjuster.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract Usr {
    address adjuster;

    constructor(address adjuster_) public {
        adjuster = adjuster_;
    }

    function callAdjuster(bytes memory data) internal {
        (bool success, ) = adjuster.call(data);
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function modifyParameters(bytes32, uint) public { callAdjuster(msg.data); }
    function modifyParameters(bytes32, address) public { callAdjuster(msg.data); }
    function modifyParameters(address, bytes4, bytes32, uint) public { callAdjuster(msg.data); }
    function addRewardAdjuster(address) public { callAdjuster(msg.data); }
    function removeRewardAdjuster(address) public { callAdjuster(msg.data); }
    function addFundedFunction(address, bytes4, uint) public { callAdjuster(msg.data); }
    function removeFundedFunction(address, bytes4) public { callAdjuster(msg.data); }
    function adjustMaxReward(address, bytes4, uint) public { callAdjuster(msg.data); }
    function setNewTreasuryParameters() public { callAdjuster(msg.data); }
}

contract SFTreasuryCoreParamAdjusterTest is DSTest {
    Hevm hevm;

    SFTreasuryCoreParamAdjuster adjuster;
    SAFEEngine safeEngine;
    Coin systemCoin;
    CoinJoin systemCoinA;
    CoreStabilityFeeTreasury public treasury;
    Usr usr;

    uint256 public updateDelay = 1 days;
    uint256 public lastUpdateTime = 604411201;
    uint256 public treasuryCapacityMultiplier = 100;
    uint256 public minTreasuryCapacity = 1000 ether;
    uint256 public minimumFundsMultiplier = 100;
    uint256 public minMinimumFunds = 1 ether;
    uint256 public pullFundsMinThresholdMultiplier = 100;
    uint256 public minPullFundsThreshold = 2 ether;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        safeEngine  = new SAFEEngine();
        systemCoin = new Coin("Coin", "COIN", 99);
        systemCoinA = new CoinJoin(address(safeEngine), address(systemCoin));
        treasury = new CoreStabilityFeeTreasury(address(safeEngine), address(0x1), address(systemCoinA));

        systemCoin.addAuthorization(address(systemCoinA));
        treasury.addAuthorization(address(systemCoinA));

        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );

        treasury.addAuthorization(address(adjuster));

        usr = new Usr(address(adjuster));
    }

    function test_setup() public {
        assertEq(address(adjuster.treasury()), address(treasury));
        assertEq(adjuster.updateDelay(), updateDelay);
        assertEq(adjuster.lastUpdateTime(), lastUpdateTime);
        assertEq(adjuster.treasuryCapacityMultiplier(), treasuryCapacityMultiplier);
        assertEq(adjuster.minTreasuryCapacity(), minTreasuryCapacity);
        assertEq(adjuster.minimumFundsMultiplier(), minimumFundsMultiplier);
        assertEq(adjuster.minMinimumFunds(), minMinimumFunds);
        assertEq(adjuster.pullFundsMinThresholdMultiplier(), pullFundsMinThresholdMultiplier);
        assertEq(adjuster.minPullFundsThreshold(), minPullFundsThreshold);
        assertEq(adjuster.authorizedAccounts(address(this)), 1);
    }

    function testFail_setup_null_treasury() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(0),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_null_updateDelay() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            0,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_lastUpdateTime() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            now,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_treasuryCapacityMultiplier() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            99,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_treasuryCapacityMultiplier2() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            1001,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_null_minTreasuryCapacity() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            0,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_minimumFundsMultiplier() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            99,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_minimumFundsMultiplier2() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            1001,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_null_minMinimumFunds() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            0,
            pullFundsMinThresholdMultiplier,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_pullFundsMinThresholdMultiplier() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            99,
            minPullFundsThreshold
        );
    }

    function testFail_setup_invalid_pullFundsMinThresholdMultiplier2() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            1001,
            minPullFundsThreshold
        );
    }

    function testFail_setup_null_minPullFundsThreshold() public {
        adjuster = new SFTreasuryCoreParamAdjuster(
            address(treasury),
            updateDelay,
            lastUpdateTime,
            treasuryCapacityMultiplier,
            minTreasuryCapacity,
            minimumFundsMultiplier,
            minMinimumFunds,
            pullFundsMinThresholdMultiplier,
            0
        );
    }

    function test_modify_parameters() public {
        adjuster.modifyParameters("updateDelay", updateDelay + 1);
        assertEq(adjuster.updateDelay(), updateDelay + 1);

        adjuster.modifyParameters("dynamicRawTreasuryCapacity", 1);
        assertEq(adjuster.dynamicRawTreasuryCapacity(), 1);

        adjuster.modifyParameters("treasuryCapacityMultiplier", treasuryCapacityMultiplier + 1);
        assertEq(adjuster.treasuryCapacityMultiplier(), treasuryCapacityMultiplier + 1);

        adjuster.modifyParameters("minimumFundsMultiplier", minimumFundsMultiplier + 1);
        assertEq(adjuster.minimumFundsMultiplier(), minimumFundsMultiplier + 1);

        adjuster.modifyParameters("pullFundsMinThresholdMultiplier", pullFundsMinThresholdMultiplier + 1);
        assertEq(adjuster.pullFundsMinThresholdMultiplier(), pullFundsMinThresholdMultiplier + 1);

        adjuster.modifyParameters("minTreasuryCapacity", minTreasuryCapacity + 1);
        assertEq(adjuster.minTreasuryCapacity(), minTreasuryCapacity + 1);

        adjuster.modifyParameters("minMinimumFunds", minMinimumFunds + 1);
        assertEq(adjuster.minMinimumFunds(), minMinimumFunds + 1);

        adjuster.modifyParameters("minPullFundsThreshold", minPullFundsThreshold + 1);
        assertEq(adjuster.minPullFundsThreshold(), minPullFundsThreshold + 1);

        adjuster.modifyParameters("treasury", address(0x123));
        assertEq(address(adjuster.treasury()), address(0x123));
    }

    function testFail_modify_parameters_null_uint() public {
        adjuster.modifyParameters("updateDelay", 0);
    }

    function testFail_modify_parameters_null_address() public {
        adjuster.modifyParameters("treasury", address(0x0));
    }

    function testFail_modify_parameters_invalid_param_uint() public {
        adjuster.modifyParameters("invalid", 1);
    }

    function testFail_modify_parameters_invalid_param_address() public {
        adjuster.modifyParameters("invalid", address(0x0));
    }

    function testFail_modify_parameters_invalid_treasuryCapacityMultiplier() public {
        adjuster.modifyParameters("treasuryCapacityMultiplier", 1001);
    }

    function testFail_modify_parameters_invalid_treasuryCapacityMultiplier2() public {
        adjuster.modifyParameters("treasuryCapacityMultiplier", 99);
    }

    function testFail_modify_parameters_invalid_minimumFundsMultiplier() public {
        adjuster.modifyParameters("minimumFundsMultiplier", 1001);
    }

    function testFail_modify_parameters_invalid_minimumFundsMultiplier2() public {
        adjuster.modifyParameters("minimumFundsMultiplier", 99);
    }

    function testFail_modify_parameters_invalid_pullFundsMinThresholdMultiplier() public {
        adjuster.modifyParameters("pullFundsMinThresholdMultiplier", 1001);
    }

    function testFail_modify_parameters_invalid_pullFundsMinThresholdMultiplier2() public {
        adjuster.modifyParameters("pullFundsMinThresholdMultiplier", 99);
    }

    function testFail_modify_parameters_uint_unauthorized() public {
        usr.modifyParameters("updateDelay", updateDelay + 1);
    }

    function testFail_modify_parameters_address_unauthorized() public {
        usr.modifyParameters("treasury", address(0x123));
    }

    function test_modify_parameters_FundedFunction() public {
        // adding a funded function
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);

        adjuster.modifyParameters(address(0x2), bytes4("0x2"), "latestExpectedCalls", 2);
        (latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 2);
    }

    function testFail_modify_parameters_inexistent_FundedFunction() public {
        adjuster.modifyParameters(address(0x2), bytes4("0x2"), "latestExpectedCalls",2);
    }

    function testFail_modify_parameters_FundedFunction_invalid_latestExpectedCalls() public {
        // adding a funded function
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);

        adjuster.modifyParameters(address(0x2), bytes4("0x2"), "latestExpectedCalls", 0);
    }

    function testFail_modify_parameters_FundedFunction_invalid_param() public {
        // adding a funded function
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);

        adjuster.modifyParameters(address(0x2), bytes4("0x2"), "invalid", 2);
    }

    function testFail_modify_parameters_FundedFunction_unauthorized() public {
        // adding a funded function
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);

        usr.modifyParameters(address(0x2), bytes4("0x2"), "latestExpectedCalls", 2);
    }

    function test_add_reward_adjuster() public {
        adjuster.addRewardAdjuster(address(0x123));
        assertEq(adjuster.rewardAdjusters(address(0x123)), 1);
    }

    function testFail_add_reward_adjuster_already_added() public {
        adjuster.addRewardAdjuster(address(0x123));
        adjuster.addRewardAdjuster(address(0x123));
    }

    function testFail_add_reward_adjuster_unauthorized() public {
        usr.addRewardAdjuster(address(0x123));
    }

    function test_remove_reward_adjuster() public {
        adjuster.addRewardAdjuster(address(0x123));
        assertEq(adjuster.rewardAdjusters(address(0x123)), 1);

        adjuster.removeRewardAdjuster(address(0x123));
        assertEq(adjuster.rewardAdjusters(address(0x123)), 0);
    }

    function testFail_remove_reward_adjuster_never_added() public {
        adjuster.removeRewardAdjuster(address(0x123));
    }

    function testFail_remove_reward_adjuster_unauthorized() public {
        adjuster.addRewardAdjuster(address(0x123));
        assertEq(adjuster.rewardAdjusters(address(0x123)), 1);

        usr.removeRewardAdjuster(address(0x123));
    }

    function test_add_FundedFunction() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);
    }

    function testFail_add_FundedFunction_already_added() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
    }

    function testFail_add_FundedFunction_invalid_latestExpectedCalls() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 0);
    }

    function testFail_add_FundedFunction_unauthorized() public {
        usr.addFundedFunction(address(0x2), bytes4("0x2"), 1);
    }

    function test_remove_FundedFunction() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);

        adjuster.removeFundedFunction(address(0x2), bytes4("0x2"));
        (latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 0);
    }

    function testFail_remove_FundedFunction_never_added() public {
        adjuster.removeFundedFunction(address(0x2), bytes4("0x2"));
    }

    function testFail_remove_FundedFunction_unauthorized() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        (uint latestExpectedCalls,) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestExpectedCalls, 1);

        usr.removeFundedFunction(address(0x2), bytes4("0x2"));
    }

    function test_adjust_max_reward() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        adjuster.addRewardAdjuster(address(usr));

        assertEq(adjuster.dynamicRawTreasuryCapacity(), 0);

        usr.adjustMaxReward(address(0x2), bytes4("0x2"), 35);
        (, uint latestMaxReward) = adjuster.whitelistedFundedFunctions(address(0x2), bytes4("0x2"));
        assertEq(latestMaxReward, 35);
        assertEq(adjuster.dynamicRawTreasuryCapacity(), 35); // fundedFunction.latestExpectedCalls * newMaxReward
    }

    function testFail_adjust_max_reward_unauthorized() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);

        usr.adjustMaxReward(address(0x2), bytes4("0x2"), 35);
    }

    function testFail_adjust_max_reward_null() public {
        adjuster.addFundedFunction(address(0x2), bytes4("0x2"), 1);
        adjuster.addRewardAdjuster(address(usr));

        usr.adjustMaxReward(address(0x2), bytes4("0x2"), 0);
    }

    function testFail_adjust_max_reward_unexistent_fundedFunction() public {
        adjuster.addRewardAdjuster(address(usr));

        usr.adjustMaxReward(address(0x2), bytes4("0x2"), 22);
    }

    function test_set_new_treasury_parameters() public {
        hevm.warp(now + adjuster.updateDelay() + 1);
        usr.setNewTreasuryParameters();

        assertEq(adjuster.lastUpdateTime(), now);

        assertEq(treasury.treasuryCapacity(), minTreasuryCapacity);
        assertEq(treasury.minimumFundsRequired(), minTreasuryCapacity);
        assertEq(treasury.pullFundsMinThreshold(), minTreasuryCapacity);
    }

    function testFail_set_new_treasury_parameters_before_delay() public {
        hevm.warp(now + adjuster.updateDelay());
        usr.setNewTreasuryParameters();
    }

    function helper_non_null(uint val) internal pure returns (uint) {
        return (val == 0) ? 1 : val;
    }

    function helper_maximum(uint a, uint b) internal pure returns (uint) {
        return (a > b) ? a : b;
    }

    function test_set_new_treasury_parameters_fuzz(
        address[6] memory addresses,
        bytes4[6]  memory sigs,
        uint256[6] memory latestExpectedCalls,
        uint256[6] memory maxRewards
    ) public {
        hevm.warp(now + 1);
        adjuster.addRewardAdjuster(address(usr));
        uint newMaxTreasuryCapacity;
        uint newMinTreasuryCapacity;
        uint newPullFundsMinThreshold;

        for (uint i = 0; i < addresses.length; i++) {
            latestExpectedCalls[i] = helper_non_null(latestExpectedCalls[i] % 100); // up to 1k calls
            maxRewards[i] = helper_non_null(maxRewards[i] % 500 ether); // up to 500 wad

            // add funded function, ignoring reverts (occur due to adding the same function twice)
            try adjuster.addFundedFunction(addresses[i], sigs[i], latestExpectedCalls[i]) {} catch {}

            // add maxReward
            usr.adjustMaxReward(addresses[i], sigs[i], maxRewards[i]);

            // setParams
            hevm.warp(now + adjuster.updateDelay() + 1);
            try usr.setNewTreasuryParameters() {
                assertEq(adjuster.lastUpdateTime(), now);

                newMaxTreasuryCapacity = adjuster.treasuryCapacityMultiplier() * adjuster.dynamicRawTreasuryCapacity() / 100 * 10**27;
                newMinTreasuryCapacity = adjuster.minimumFundsMultiplier() * newMaxTreasuryCapacity / 100;
                newPullFundsMinThreshold = adjuster.pullFundsMinThresholdMultiplier() * newMaxTreasuryCapacity / 100;

                assertEq(treasury.treasuryCapacity(), helper_maximum(minTreasuryCapacity, newMaxTreasuryCapacity));
                assertEq(treasury.minimumFundsRequired(), helper_maximum(minMinimumFunds, newMinTreasuryCapacity));
                assertEq(treasury.pullFundsMinThreshold(), helper_maximum(minPullFundsThreshold, newPullFundsMinThreshold));
            } catch { // allowing for reverting when capacity lower than min funds
                assertTrue(adjuster.lastUpdateTime() != now);
            }
        }
    }
}