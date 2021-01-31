pragma solidity 0.6.7;

abstract contract StabilityFeeTreasuryLike {
    function treasuryCapacity() virtual public view returns (uint256);
    function minimumFundsRequired() virtual public view returns (uint256);
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

    // --- Variables ---
    uint256                  public updateDelay;                       // [seconds]
    uint256                  public lastUpdateTime;                    // [unit timestamp]
    uint256                  public treasuryCapacityTargetValue;       // [ray]
    uint256                  public minTreasuryCapacity;               // [rad]
    uint256                  public minimumFundsTargetValue;           // [ray]
    uint256                  public minMinimumFunds;                   // [rad]
    uint256                  public pullFundsMinThresholdTargetValue;  // [ray]
    uint256                  public minPullFundsThreshold;             // [rad]

    OracleRelayerLike        public oracleRelayer;
    StabilityFeeTreasuryLike public treasury;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(bytes32 parameter, uint256 val);
    event ModifyParameters(bytes32 parameter, address addr);
    event UpdateTreasuryParameters(uint256 newMinPullFundsThreshold, uint256 newMinimumFunds, uint256 newTreasuryCapacity);

    constructor(
      address treasury_,
      address oracleRelayer_,
      uint256 updateDelay_,
      uint256 lastUpdateTime_,
      uint256 treasuryCapacityTargetValue_,
      uint256 minTreasuryCapacity_,
      uint256 minimumFundsTargetValue_,
      uint256 minMinimumFunds_,
      uint256 pullFundsMinThresholdTargetValue_,
      uint256 minPullFundsThreshold_
    ) public {
        require(treasury_ != address(0), "TreasuryCoreParamAdjuster/null-treasury");
        require(oracleRelayer_ != address(0), "TreasuryCoreParamAdjuster/null-oracle-relayer");
        require(updateDelay_ > 0, "TreasuryCoreParamAdjuster/null-update-delay");
        require(lastUpdateTime_ > now, "TreasuryCoreParamAdjuster/invalid-last-update-time");
        require(treasuryCapacityTargetValue_ > 0, "TreasuryCoreParamAdjuster/null-capacity-value");
        require(minimumFundsTargetValue_ > 0, "TreasuryCoreParamAdjuster/null-min-funds-value");
        require(minTreasuryCapacity_ > 0, "TreasuryCoreParamAdjuster/invalid-min-capacity");
        require(minMinimumFunds_ > 0, "TreasuryCoreParamAdjuster/invalid-min-minimum-funds");
        require(pullFundsMinThresholdTargetValue_ > 0, "TreasuryCoreParamAdjuster/null-pull-funds-threshold-value");
        require(minPullFundsThreshold_ > 0, "TreasuryCoreParamAdjuster/null-min-pull-funds-threshold");

        authorizedAccounts[msg.sender]   = 1;

        treasury                         = StabilityFeeTreasuryLike(treasury_);
        oracleRelayer                    = OracleRelayerLike(oracleRelayer_);

        updateDelay                      = updateDelay_;
        lastUpdateTime                   = lastUpdateTime_;
        treasuryCapacityTargetValue      = treasuryCapacityTargetValue_;
        minTreasuryCapacity              = minTreasuryCapacity_;
        minimumFundsTargetValue          = minimumFundsTargetValue_;
        minMinimumFunds                  = minMinimumFunds_;
        pullFundsMinThresholdTargetValue = pullFundsMinThresholdTargetValue_;
        minPullFundsThreshold            = minPullFundsThreshold_;

        emit AddAuthorization(msg.sender);
        emit ModifyParameters("treasury", treasury_);
        emit ModifyParameters("oracleRelayer", oracleRelayer_);
        emit ModifyParameters("updateDelay", updateDelay);
        emit ModifyParameters("lastUpdateTime", lastUpdateTime);
        emit ModifyParameters("minTreasuryCapacity", minTreasuryCapacity);
        emit ModifyParameters("minMinimumFunds", minMinimumFunds);
        emit ModifyParameters("treasuryCapacityTargetValue", treasuryCapacityTargetValue);
        emit ModifyParameters("minimumFundsTargetValue", minimumFundsTargetValue);
        emit ModifyParameters("pullFundsMinThresholdTargetValue", pullFundsMinThresholdTargetValue);
        emit ModifyParameters("minPullFundsThreshold", minPullFundsThreshold);
    }

    // --- Math ---
    uint256 public constant RAY  = 10 ** 27;
    uint256 public constant WAD  = 10 ** 18;
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
        else if (parameter == "treasuryCapacityTargetValue") {
            treasuryCapacityTargetValue = val;
        }
        else if (parameter == "minimumFundsTargetValue") {
            minimumFundsTargetValue = val;
        }
        else if (parameter == "minTreasuryCapacity") {
            minTreasuryCapacity = val;
        }
        else if (parameter == "minMinimumFunds") {
            minMinimumFunds = val;
        }
        else if (parameter == "pullFundsMinThresholdTargetValue") {
            pullFundsMinThresholdTargetValue = val;
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
        else revert("TreasuryCoreParamAdjuster/modify-unrecognized-param");
        emit ModifyParameters(parameter, addr);
    }

    // --- Core Logic ---
    function recomputeTreasuryParameters() external {
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
    }
}
