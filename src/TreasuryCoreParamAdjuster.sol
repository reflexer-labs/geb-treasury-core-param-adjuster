pragma solidity 0.6.7;

abstract contract StabilityFeeTreasuryLike {
    function modifyParameters(bytes32, uint256) virtual external;
}
abstract contract OracleRelayerLike {
    function redemptionPrice() virtual public returns (uint256);
}

contract TreasuryCoreParamAdjuster {
    // --- Authorities ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address account) external isAuthorized { authorizedAccounts[account] = 1; emit AddAuthorization(account); }
    function removeAuthorization(address account) external isAuthorized { authorizedAccounts[account] = 0; emit RemoveAuthorization(account); }
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "TreasuryCoreParamAdjuster/not-an-authority");
        _;
    }

    // --- Structs ---
    struct FundedFunction {
        uint256 latestExpectedCalls;
        uint256 latestMaxReward;      // [wad]
    }

    // --- Variables ---
    uint256                  public updateDelay;                       // [seconds]
    uint256                  public lastUpdateTime;                    // [unit timestamp]
    uint256                  public dynamicRawTreasuryCapacity;        // [wad]
    uint256                  public treasuryCapacityMultiplier;        // [hundred]
    uint256                  public minTreasuryCapacity;               // [rad]
    uint256                  public minimumFundsMultiplier;            // [hundred]
    uint256                  public minMinimumFunds;                   // [rad]
    uint256                  public pullFundsMinThresholdMultiplier;   // [hundred]
    uint256                  public minPullFundsThreshold;             // [rad]

    address                  public rewardAdjuster;

    mapping(address => mapping(bytes4 => FundedFunction)) public whitelistedFundedFunctions;

    OracleRelayerLike        public oracleRelayer;
    StabilityFeeTreasuryLike public treasury;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(bytes32 parameter, uint256 val);
    event ModifyParameters(bytes32 parameter, address addr);
    event ModifyParameters(address targetContract, bytes4 targetFunction, bytes32 parameter, uint256 val);
    event AddFundedFunction(address targetContract, bytes4 targetFunction, uint256 latestExpectedCalls);
    event RemoveFundedFunction(address targetContract, bytes4 targetFunction);
    event UpdateTreasuryParameters(uint256 newMinPullFundsThreshold, uint256 newMinimumFunds, uint256 newTreasuryCapacity);

    constructor(
      address treasury_,
      address oracleRelayer_,
      address rewardAdjuster_,
      uint256 updateDelay_,
      uint256 lastUpdateTime_,
      uint256 treasuryCapacityMultiplier_,
      uint256 minTreasuryCapacity_,
      uint256 minimumFundsMultiplier_,
      uint256 minMinimumFunds_,
      uint256 pullFundsMinThresholdMultiplier_,
      uint256 minPullFundsThreshold_
    ) public {
        require(treasury_ != address(0), "TreasuryCoreParamAdjuster/null-treasury");
        require(oracleRelayer_ != address(0), "TreasuryCoreParamAdjuster/null-oracle-relayer");
        require(rewardAdjuster_ != address(0), "TreasuryCoreParamAdjuster/null-reward-adjuster");

        require(updateDelay_ > 0, "TreasuryCoreParamAdjuster/null-update-delay");
        require(lastUpdateTime_ > now, "TreasuryCoreParamAdjuster/invalid-last-update-time");
        require(both(treasuryCapacityMultiplier_ > 0, treasuryCapacityMultiplier_ <= THOUSAND), "TreasuryCoreParamAdjuster/invalid-capacity-mul");
        require(minTreasuryCapacity_ > 0, "TreasuryCoreParamAdjuster/invalid-min-capacity");
        require(both(minimumFundsMultiplier_ > 0, minimumFundsMultiplier_ <= THOUSAND), "TreasuryCoreParamAdjuster/invalid-min-funds-mul");
        require(minMinimumFunds_ > 0, "TreasuryCoreParamAdjuster/null-min-minimum-funds");
        require(both(pullFundsMinThresholdMultiplier_ > 0, pullFundsMinThresholdMultiplier_ <= THOUSAND), "TreasuryCoreParamAdjuster/invalid-pull-funds-threshold-mul");
        require(minPullFundsThreshold_ > 0, "TreasuryCoreParamAdjuster/null-min-pull-funds-threshold");

        authorizedAccounts[msg.sender]   = 1;

        treasury                         = StabilityFeeTreasuryLike(treasury_);
        oracleRelayer                    = OracleRelayerLike(oracleRelayer_);
        rewardAdjuster                   = rewardAdjuster_;

        updateDelay                      = updateDelay_;
        lastUpdateTime                   = lastUpdateTime_;
        treasuryCapacityMultiplier       = treasuryCapacityMultiplier_;
        minTreasuryCapacity              = minTreasuryCapacity_;
        minimumFundsMultiplier           = minimumFundsMultiplier_;
        minMinimumFunds                  = minMinimumFunds_;
        pullFundsMinThresholdMultiplier  = pullFundsMinThresholdMultiplier_;
        minPullFundsThreshold            = minPullFundsThreshold_;

        emit AddAuthorization(msg.sender);
        emit ModifyParameters("treasury", treasury_);
        emit ModifyParameters("oracleRelayer", oracleRelayer_);
        emit ModifyParameters("updateDelay", updateDelay);
        emit ModifyParameters("lastUpdateTime", lastUpdateTime);
        emit ModifyParameters("minTreasuryCapacity", minTreasuryCapacity);
        emit ModifyParameters("minMinimumFunds", minMinimumFunds);
        emit ModifyParameters("minPullFundsThreshold", minPullFundsThreshold);
        emit ModifyParameters("treasuryCapacityMultiplier", treasuryCapacityMultiplier);
        emit ModifyParameters("minimumFundsMultiplier", minimumFundsMultiplier);
        emit ModifyParameters("pullFundsMinThresholdMultiplier", pullFundsMinThresholdMultiplier);
    }

    // --- Math ---
    uint256 public constant RAY      = 10 ** 27;
    uint256 public constant WAD      = 10 ** 18;
    uint256 public constant THOUSAND = 1000;
    function addition(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "TreasuryCoreParamAdjuster/add-uint-uint-overflow");
    }
    function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "TreasuryCoreParamAdjuster/sub-uint-uint-underflow");
    }
    function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "TreasuryCoreParamAdjuster/multiply-uint-uint-overflow");
    }
    function maximum(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x >= y) ? x : y;
    }

    // --- Boolean Logic ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }

    // --- Administration ---
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
        require(val > 0, "TreasuryCoreParamAdjuster/null-value");

        if (parameter == "updateDelay") {
            updateDelay = val;
        }
        else if (parameter == "dynamicRawTreasuryCapacity") {
            dynamicRawTreasuryCapacity = val;
        }
        else if (parameter == "treasuryCapacityMultiplier") {
            require(val <= THOUSAND, "TreasuryCoreParamAdjuster/invalid-capacity-mul");
            treasuryCapacityMultiplier = val;
        }
        else if (parameter == "minimumFundsMultiplier") {
            require(val <= THOUSAND, "TreasuryCoreParamAdjuster/invalid-min-funds-mul");
            minimumFundsMultiplier = val;
        }
        else if (parameter == "pullFundsMinThresholdMultiplier") {
            require(val <= THOUSAND, "TreasuryCoreParamAdjuster/invalid-pull-funds-threshold-mul");
            pullFundsMinThresholdMultiplier = val;
        }
        else if (parameter == "minTreasuryCapacity") {
            minTreasuryCapacity = val;
        }
        else if (parameter == "minMinimumFunds") {
            minMinimumFunds = val;
        }
        else if (parameter == "minPullFundsThreshold") {
            minPullFundsThreshold = val;
        }
        else revert("TreasuryCoreParamAdjuster/modify-unrecognized-param");
        emit ModifyParameters(parameter, val);
    }
    function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
        require(addr != address(0), "TreasuryCoreParamAdjuster/null-address");

        if (parameter == "oracleRelayer") {
            oracleRelayer = OracleRelayerLike(addr);
        }
        else if (parameter == "treasury") {
            treasury = StabilityFeeTreasuryLike(addr);
        }
        else if (parameter == "rewardAdjuster") {
            rewardAdjuster = addr;
        }
        else revert("TreasuryCoreParamAdjuster/modify-unrecognized-param");
        emit ModifyParameters(parameter, addr);
    }
    function modifyParameters(address targetContract, bytes4 targetFunction, bytes32 parameter, uint256 val) external isAuthorized {
        FundedFunction storage fundedFunction = whitelistedFundedFunctions[targetContract][targetFunction];
        require(fundedFunction.latestExpectedCalls >= 1, "TreasuryCoreParamAdjuster/inexistent-funded-function");
        require(val >= 1, "TreasuryCoreParamAdjuster/invalid-value");

        if (parameter == "latestExpectedCalls") {
            dynamicRawTreasuryCapacity = subtract(dynamicRawTreasuryCapacity, multiply(fundedFunction.latestExpectedCalls, fundedFunction.latestMaxReward));
            fundedFunction.latestExpectedCalls = val;
            dynamicRawTreasuryCapacity = addition(dynamicRawTreasuryCapacity, multiply(val, fundedFunction.latestMaxReward));
        }
        else revert("TreasuryCoreParamAdjuster/modify-unrecognized-param");
        emit ModifyParameters(targetContract, targetFunction, parameter, val);
    }

    // --- Funded Function Management ---
    function addFundedFunction(address targetContract, bytes4 targetFunction, uint256 latestExpectedCalls) external isAuthorized {
        FundedFunction storage fundedFunction = whitelistedFundedFunctions[targetContract][targetFunction];
        require(fundedFunction.latestExpectedCalls == 0, "TreasuryCoreParamAdjuster/existent-funded-function");

        // Update the entry
        require(latestExpectedCalls >= 1, "TreasuryCoreParamAdjuster/invalid-expected-calls");
        fundedFunction.latestExpectedCalls = latestExpectedCalls;

        // Emit the event
        emit AddFundedFunction(targetContract, targetFunction, latestExpectedCalls);
    }
    function removeFundedFunction(address targetContract, bytes4 targetFunction) external isAuthorized {
        FundedFunction memory fundedFunction = whitelistedFundedFunctions[targetContract][targetFunction];
        require(fundedFunction.latestExpectedCalls >= 1, "TreasuryCoreParamAdjuster/inexistent-funded-function");

        // Update the dynamic capacity
        dynamicRawTreasuryCapacity = subtract(
          dynamicRawTreasuryCapacity,
          multiply(fundedFunction.latestExpectedCalls, fundedFunction.latestMaxReward)
        );

        // Delete the entry from the mapping
        delete(whitelistedFundedFunctions[targetContract][targetFunction]);

        // Emit the event
        emit RemoveFundedFunction(targetContract, targetFunction);
    }

    // --- Reward Adjuster Logic ---
    function adjustMaxReward(address receiver, bytes4 targetFunctionSignature, uint256 newMaxReward) external {
        require(rewardAdjuster == msg.sender, "TreasuryCoreParamAdjuster/invalid-caller");
    }

    // --- Core Logic ---
    /* function recomputeTreasuryParameters() external {
        require(both(lastUpdateTime < now, subtract(now, lastUpdateTime) >= updateDelay), "TreasuryCoreParamAdjuster/wait-more");
        lastUpdateTime = now;

        // Calculate new params
        uint256 latestRedemptionPrice    = oracleRelayer.redemptionPrice();

        uint256 newTreasuryCapacity      = multiply(multiply(treasuryCapacityTargetValue, WAD) / latestRedemptionPrice, RAY);
        newTreasuryCapacity              = maximum(newTreasuryCapacity, minTreasuryCapacity);

        uint256 newMinimumFunds          = multiply(multiply(minimumFundsTargetValue, WAD) / latestRedemptionPrice, RAY);
        newMinimumFunds                  = maximum(newMinimumFunds, minMinimumFunds);

        uint256 newMinPullFundsThreshold = multiply(multiply(pullFundsMinThresholdTargetValue, WAD) / latestRedemptionPrice, RAY);
        newMinPullFundsThreshold         = maximum(newMinPullFundsThreshold, minPullFundsThreshold);

        // Set parameters
        treasury.modifyParameters("pullFundsMinThreshold", newMinPullFundsThreshold);
        treasury.modifyParameters("minimumFundsRequired", newMinimumFunds);
        treasury.modifyParameters("treasuryCapacity", newTreasuryCapacity);

        emit UpdateTreasuryParameters(newMinPullFundsThreshold, newMinimumFunds, newTreasuryCapacity);
    } */
}
