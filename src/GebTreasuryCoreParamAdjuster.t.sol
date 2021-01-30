pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebTreasuryCoreParamAdjuster.sol";

contract GebTreasuryCoreParamAdjusterTest is DSTest {
    GebTreasuryCoreParamAdjuster adjuster;

    function setUp() public {
        adjuster = new GebTreasuryCoreParamAdjuster();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
