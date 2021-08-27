# Security Tests

The contracts in this folder are the fuzz scripts for the rewards adjusters.

To run the fuzzer, set up Echidna (https://github.com/crytic/echidna) on your machine.

Then run
```
echidna-test src/test/fuzz/<name of file>.sol --contract <Name of contract> --config src/test/fuzz/echidna.yaml
```

Configs are in this folder (echidna.yaml).

The contracts in this folder are modified versions of the originals in the _src_ folder. They have assertions added to test for invariants, visibility of functions modified. Running the Fuzz against modified versions without the assertions is still possible, general properties on the Fuzz contract can be executed against unmodified contracts.

Tests should be run one at a time because they interfere with each other.

For all contracts being fuzzed, we tested the following:

1. Writing assertions and/or turning "requires" into "asserts" within the smart contract itself. This will cause echidna to fail fuzzing, and upon failures echidna finds the lowest value that causes the assertion to fail. This is useful to test bounds of functions (i.e.: modifying safeMath functions to assertions will cause echidna to fail on overflows, giving insight on the bounds acceptable). This is useful to find out when these functions revert. Although reverting will not impact the contract's state, it could cause a denial of service (or the contract not updating state when necessary and getting stuck). We check the found bounds against the expected usage of the system.
2. For contracts that have state, we also force the contract into common states and fuzz common actions.

Echidna will generate random values and call all functions failing either for violated assertions, or for properties (functions starting with echidna_) that return false. Sequence of calls is limited by seqLen in the config file. Calls are also spaced over time (both block number and timestamp) in random ways. Once the fuzzer finds a new execution path, it will explore it by trying execution with values close to the ones that opened the new path.

# Results

### 1. Fuzzing the fixed rewards adjuster for bounds

In this test (contract Fuzz in SFTreasuryCoreParamAdjusterMock.sol) we test for overflows (overflows will be flagged as failures). the contract also creates and fuzzes a a funded function and calls adjust max rewards and adjust treasury params (this is to increase effectiveness of the script, the fuzzer eventually finds it's way to creating a funding receiver and then recomputing its rewards but it takes many times longer. The usual functions remain open so the fuzzer can and will execute with others).

Whenever it recomputes max rewards or treasury params it asserts the the calculations went as expected.

```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-treasury-core-param-adjuster/src/test/fuzz/SFTreasuryCoreParamAdjusterFuzz.sol:Fuzz
echidna_pullFundsMinThreshold: passed! 🎉
echidna_minimumFundsRequired: passed! 🎉
echidna_treasuryCapacity: passed! 🎉
assertion in pullFundsMinThresholdMultiplier: passed! 🎉
assertion in minTreasuryCapacity: passed! 🎉
assertion in adjustMaxReward: passed! 🎉
assertion in authorizedAccounts: passed! 🎉
assertion in addRewardAdjuster: passed! 🎉
assertion in addAuthorization: passed! 🎉
assertion in addFundedFunction: passed! 🎉
assertion in setNewTreasuryParameters: failed!💥
  Call sequence:
    fuzz_adjust_max_reward(1159975465020996764214545813718742371498818562879)
    setNewTreasuryParameters() Time delay: 3603 seconds Block delay: 1

assertion in RAY: passed! 🎉
assertion in updateDelay: passed! 🎉
assertion in treasury: passed! 🎉
assertion in modifyParameters: passed! 🎉
assertion in WAD: passed! 🎉
assertion in fuzz_adjust_treasury_params: passed! 🎉
assertion in removeFundedFunction: passed! 🎉
assertion in treasuryCapacityMultiplier: passed! 🎉
assertion in THOUSAND: passed! 🎉
assertion in removeRewardAdjuster: passed! 🎉
assertion in removeAuthorization: passed! 🎉
assertion in whitelistedFundedFunctions: passed! 🎉
assertion in rewardAdjusters: passed! 🎉
assertion in lastUpdateTime: passed! 🎉
assertion in dynamicRawTreasuryCapacity: passed! 🎉
assertion in minMinimumFunds: passed! 🎉
assertion in modifyParameters: passed! 🎉
assertion in minPullFundsThreshold: passed! 🎉
assertion in HUNDRED: passed! 🎉
assertion in fuzz_adjust_max_reward: passed! 🎉
assertion in modifyParameters: passed! 🎉
assertion in minimumFundsMultiplier: passed! 🎉

Seed: -1629574820516391638
```

We found one failure, with maxReward of 1159,975,465,020,996,764,214,545,813,718.742371498818562879 (for one function, in practice this would be the sum of all maxRewards). This was tested with the minimum multiplier of 100, it can go up to 1000.

#### Conclusion: No exceptions noted, bounds are plentyful

### 2. Fuzzing the fixed rewards with property tests

In this test (same contract as in the previous test) we are testing basic properties. The contract will be fuzzed as previously ans the following properties are tested.

- Bounds of Treasury capacity
- Bounds of Minimum funds required
- Bounds of Pull Funds min threshold

```
Analyzing contract: /Users/fabio/Documents/reflexer/geb-treasury-core-param-adjuster/src/test/fuzz/SFTreasuryCoreParamAdjusterFuzz.sol:Fuzz
echidna_pullFundsMinThreshold: passed! 🎉
echidna_minimumFundsRequired: passed! 🎉
echidna_treasuryCapacity: passed! 🎉

Seed: 9146195736555885504
```

#### Conclusion: No exceptions noted



