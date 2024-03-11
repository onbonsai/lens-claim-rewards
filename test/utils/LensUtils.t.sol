// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "lib/core/test/mocks/MockCurrency.sol";
import "lib/core/test/base/BaseTest.t.sol";
import {ValidationLib} from "lens/libraries/ValidationLib.sol";

contract LensUtils is BaseTest {
    MockCurrency token;
    TestAccount user;
    TestAccount user2;
    TestAccount user3;
    address defaultTransactionExecutor = address(0x69);

    function setUp() public virtual override {
        super.setUp();

        // create some profiles
        user = _loadAccountAs("USER");
        user2 = _loadAccountAs("USER2");
        user3 = _loadAccountAs("USER3");

        // set profile manager for user2
        vm.prank(user2.owner);
        hub.changeDelegatedExecutorsConfig({
            delegatorProfileId: user2.profileId,
            delegatedExecutors: _toAddressArray(defaultTransactionExecutor),
            approvals: _toBoolArray(true)
        });

        // currency to use for rewards
        token = new MockCurrency();
        token.mint(address(this), 10000 ether);
    }
}