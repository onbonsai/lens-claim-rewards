// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "lib/core/test/base/BaseTest.t.sol";

contract LensUtils is BaseTest {
    TestAccount creator;
    TestAccount user;
    TestAccount user2;
    TestPublication creatorPub;
    address defaultTransactionExecutor = address(0x69);

    function setUp() public virtual override {
        super.setUp();

        // create some profiles
        creator = _loadAccountAs("CREATOR");
        user = _loadAccountAs("USER");
        user2 = _loadAccountAs("USER2");

        // creator sets up mad sbt collection + a lens pub to init the action module with
        vm.prank(creator.owner);
        creatorPub = TestPublication(creator.profileId, hub.post(_getCreatorPostParams()));

        // set the delegated executor so tests don't fail
        vm.prank(creator.owner);
        hub.changeDelegatedExecutorsConfig({
            delegatorProfileId: creator.profileId,
            delegatedExecutors: _toAddressArray(defaultTransactionExecutor),
            approvals: _toBoolArray(true)
        });

        vm.prank(user.owner);
        hub.changeDelegatedExecutorsConfig({
            delegatorProfileId: user.profileId,
            delegatedExecutors: _toAddressArray(defaultTransactionExecutor),
            approvals: _toBoolArray(true)
        });

        vm.prank(user2.owner);
        hub.changeDelegatedExecutorsConfig({
            delegatorProfileId: user2.profileId,
            delegatedExecutors: _toAddressArray(defaultTransactionExecutor),
            approvals: _toBoolArray(true)
        });
    }

    function _getCreatorPostParams() internal view returns (Types.PostParams memory) {
        return
            Types.PostParams({
                profileId: creator.profileId,
                contentURI: MOCK_URI,
                actionModules: _toAddressArray(address(mockActionModule)),
                actionModulesInitDatas: _toBytesArray(abi.encode(true)),
                referenceModule: address(0),
                referenceModuleInitData: ''
            });
    }

    function _getAccountPostParams(TestAccount memory account, bool withOpenAction) internal view returns (Types.PostParams memory) {
        return
            Types.PostParams({
                profileId: account.profileId,
                contentURI: MOCK_URI,
                actionModules: withOpenAction ? _toAddressArray(address(mockActionModule)) : _emptyAddressArray(),
                actionModulesInitDatas: withOpenAction ? _toBytesArray(abi.encode(true)) : _emptyBytesArray(),
                referenceModule: address(0),
                referenceModuleInitData: ''
            });
    }

    function _getAccountCommentParams(
        TestAccount memory account,
        uint256 pointedProfileId,
        uint256 pointedPubId
    ) internal pure returns (Types.CommentParams memory) {
        return
            Types.CommentParams({
                profileId: account.profileId,
                pointedProfileId: pointedProfileId,
                pointedPubId: pointedPubId,
                contentURI: MOCK_URI,
                referrerProfileIds: _emptyUint256Array(),
                referrerPubIds: _emptyUint256Array(),
                actionModules: _emptyAddressArray(),
                actionModulesInitDatas: _emptyBytesArray(),
                referenceModule: address(0),
                referenceModuleData: "",
                referenceModuleInitData: ""
            });
    }

    function _getAccountCommentParamsSig(
        TestAccount memory account,
        Types.CommentParams memory commentParams
    ) internal view returns (Types.EIP712Signature memory) {
        return _getSigStruct({
            pKey: account.ownerPk,
            digest: _getCommentTypedDataHash({
                commentParams: commentParams,
                nonce: hub.nonces(account.owner),
                deadline: type(uint256).max
            }),
            deadline: type(uint256).max
        });
    }

    function _getAccountMirrorParams(
        TestAccount memory account,
        uint256 pointedProfileId,
        uint256 pointedPubId
    ) internal pure returns (Types.MirrorParams memory) {
        return
            Types.MirrorParams({
                pointedProfileId: pointedProfileId,
                pointedPubId: pointedPubId,
                profileId: account.profileId,
                metadataURI: "",
                referrerProfileIds: _emptyUint256Array(),
                referrerPubIds: _emptyUint256Array(),
                referenceModuleData: ""
            });
    }

    function _getAccountMirrorParamsSig(
        TestAccount memory account,
        Types.MirrorParams memory mirrorParams
    ) internal view returns (Types.EIP712Signature memory) {
        return _getSigStruct({
            pKey: account.ownerPk,
            digest: _getMirrorTypedDataHash({
                mirrorParams: mirrorParams,
                nonce: hub.nonces(account.owner),
                deadline: type(uint256).max
            }),
            deadline: type(uint256).max
        });
    }

    function _getAccountQuoteParams(
        TestAccount memory account,
        uint256 pointedProfileId,
        uint256 pointedPubId
    ) internal pure returns (Types.QuoteParams memory) {
        return
            Types.QuoteParams({
                pointedProfileId: pointedProfileId,
                pointedPubId: pointedPubId,
                profileId: account.profileId,
                contentURI: "",
                referrerProfileIds: _emptyUint256Array(),
                referrerPubIds: _emptyUint256Array(),
                referenceModuleData: "",
                actionModules: _emptyAddressArray(),
                actionModulesInitDatas: _emptyBytesArray(),
                referenceModule: address(0),
                referenceModuleInitData: ""
            });
    }

    function _getAccountQuoteParamsSig(
        TestAccount memory account,
        Types.QuoteParams memory quoteParams
    ) internal view returns (Types.EIP712Signature memory) {
        return _getSigStruct({
            pKey: account.ownerPk,
            digest: _getQuoteTypedDataHash({
                quoteParams: quoteParams,
                nonce: hub.nonces(account.owner),
                deadline: type(uint256).max
            }),
            deadline: type(uint256).max
        });
    }

    function _getProcessActionParams(
        TestAccount memory actor,
        bytes memory actionModuleData
    ) internal view returns (Types.ProcessActionParams memory) {
        return
            Types.ProcessActionParams({
                publicationActedProfileId: creator.profileId,
                publicationActedId: creatorPub.pubId,
                actorProfileId: actor.profileId,
                actorProfileOwner: actor.owner,
                transactionExecutor: defaultTransactionExecutor,
                referrerProfileIds: _emptyUint256Array(),
                referrerPubIds: _emptyUint256Array(),
                referrerPubTypes: _emptyPubTypesArray(),
                actionModuleData: actionModuleData
            });
    }

    function _getProcessActionParamsAsExecutor(
        TestAccount memory actor,
        bytes memory actionModuleData
    ) internal view returns (Types.ProcessActionParams memory) {
        return
            Types.ProcessActionParams({
                publicationActedProfileId: creator.profileId,
                publicationActedId: creatorPub.pubId,
                actorProfileId: actor.profileId,
                actorProfileOwner: actor.owner,
                transactionExecutor: actor.owner,
                referrerProfileIds: _emptyUint256Array(),
                referrerPubIds: _emptyUint256Array(),
                referrerPubTypes: _emptyPubTypesArray(),
                actionModuleData: actionModuleData
            });
    }

    function _getProcessActionParamsAsExecutorWithReferrerPubIds(
        TestAccount memory actor,
        bytes memory actionModuleData,
        uint256[] memory referrerProfileIds,
        uint256[] memory referrerPubIds,
        Types.PublicationType[] memory referrerPubTypes
    ) internal view returns (Types.ProcessActionParams memory) {
        return
            Types.ProcessActionParams({
                publicationActedProfileId: creator.profileId,
                publicationActedId: creatorPub.pubId,
                actorProfileId: actor.profileId,
                actorProfileOwner: actor.owner,
                transactionExecutor: actor.owner,
                referrerProfileIds: referrerProfileIds,
                referrerPubIds: referrerPubIds,
                referrerPubTypes: referrerPubTypes,
                actionModuleData: actionModuleData
            });
    }
}