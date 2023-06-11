// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./Address.sol";

import "./interface/IVault.sol";
import "./interface/IGaugeController.sol";
import "./interface/IGaugeAdder.sol";
import "./interface/IBALTokenHolder.sol";
import "./interface/ILiquidityGauge.sol";
import "./interface/IBALTokenHolderFactory.sol";
import "./interface/ILiquidityGaugeFactory.sol";

contract AuthorizerAdaptor is AccessControlEnumerableUpgradeable {
  using Address for address;

  bytes32 private _actionIdDisambiguator;
  IVault private _vault;

  address[] private _gauges;

  modifier onlyAdmin() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
      "AuthorizerAdaptor: caller is not admin"
    );
    _;
  }

  function initialize(IVault vault_) public initializer {
    __AccessControlEnumerable_init();

    _actionIdDisambiguator = bytes32(uint256(uint160(address(this))) << 96);
    _vault = vault_;

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function getGauges() public view returns (address[] memory) {
    return _gauges;
  }

  function setup(address gaugeController, address veBALGaugeRecipient) public {
    // IGaugeController(gaugeController).add_type("Liquidity Mining Committee", 0);
    // IGaugeController(gaugeController).add_type("veBAL", 0);
    // IGaugeController(gaugeController).add_type("Ethereum", 0);

    // _createSingleRecipientGauge(
    //   IGaugeAdder.GaugeType.veBAL,
    //   "Temporary veBAL Liquidity Mining BAL Holder",
    //   veBALGaugeRecipient
    // );

    ILiquidityGaugeFactory _ethereumGaugeFactory = ILiquidityGaugeFactory(
      0x8f008aF430d589D9f5F09d5c7f38F45E2EdAb4a9
    );

    IGaugeAdder _gaugeAdder = IGaugeAdder(
      0xeEeca35ef2B074C97f5DbF22e1fa5BE840B03311
    );

    // _gaugeAdder.addGaugeFactory(
    //   _ethereumGaugeFactory,
    //   IGaugeAdder.GaugeType.Ethereum
    // );

    {
      // 0xd92e2e3c13c3712af12e4389ee37b67021318812000200000000000000000002
      //0xD92e2e3C13c3712Af12E4389ee37b67021318812
      ILiquidityGauge gauge = ILiquidityGauge(
        _ethereumGaugeFactory.create(
          0xD92e2e3C13c3712Af12E4389ee37b67021318812,
          20000000000000000
        )
      );

      _gaugeAdder.addEthereumGauge(IStakingLiquidityGauge(address(gauge)));

      _gauges.push(address(gauge));
    }

    {
      // 0x900e9ae430c8f011ab9250c9d4a3a8055ebd3bb8000200000000000000000003
      //0x900E9Ae430C8F011ab9250C9d4a3a8055EbD3bb8
      ILiquidityGauge gauge = ILiquidityGauge(
        _ethereumGaugeFactory.create(
          0x900E9Ae430C8F011ab9250C9d4a3a8055EbD3bb8,
          20000000000000000
        )
      );

      _gaugeAdder.addEthereumGauge(IStakingLiquidityGauge(address(gauge)));

      _gauges.push(address(gauge));
    }
  }

  function _addGauge(
    ILiquidityGauge gauge,
    IGaugeAdder.GaugeType gaugeType
  ) private {
    IGaugeController _gaugeController = IGaugeController(
      0x782896795C815d833D1d25C9cAf418AeE57Aa011
    );
    _gaugeController.add_gauge(address(gauge), int128(uint128(gaugeType)));
  }

  function _createSingleRecipientGauge(
    IGaugeAdder.GaugeType gaugeType,
    string memory name,
    address recipient
  ) private {
    IBALTokenHolderFactory _balTokenHolderFactory = IBALTokenHolderFactory(
      0xd2d7F457B9749B6A0A637685A65681F03116125C
    );
    ILiquidityGaugeFactory _singleRecipientGaugeFactory = ILiquidityGaugeFactory(
        0xAB8467D5ba051a761310E6FABC60F00B22f9f2de
      );

    IBALTokenHolder holder = _balTokenHolderFactory.create(name);
    ILiquidityGauge gauge = ILiquidityGauge(
      _singleRecipientGaugeFactory.create(
        address(holder),
        20000000000000000,
        false
      )
    );
    _addGauge(gauge, gaugeType);

    _gauges.push(address(gauge));
  }

  function setVault(IVault vault_) public onlyAdmin {
    _vault = vault_;
  }

  /**
   * @notice Returns the Balancer Vault
   */
  function getVault() public view returns (IVault) {
    return _vault;
  }

  /**
   * @notice Returns the Authorizer
   */
  function getAuthorizer() public view returns (IAuthorizer) {
    return getVault().getAuthorizer();
  }

  function _canPerform(
    bytes32 actionId,
    address account,
    address where
  ) internal view returns (bool) {
    return getAuthorizer().canPerform(actionId, account, where);
  }

  /**
   * @notice Returns the action ID associated with calling a given function through this adaptor
   * @dev As the contracts managed by this adaptor don't have action ID disambiguators, we use the adaptor's globally.
   * This means that contracts with the same function selector will have a matching action ID:
   * if granularity is required then permissions must not be granted globally in the Authorizer.
   *
   * @param selector - The 4 byte selector of the function to be called using `performAction`
   * @return The associated action ID
   */
  function getActionId(bytes4 selector) public view returns (bytes32) {
    return keccak256(abi.encodePacked(_actionIdDisambiguator, selector));
  }

  /**
   * @notice Performs an arbitrary function call on a target contract, provided the caller is authorized to do so.
   *
   * This function should not be called directly as that will result in an unconditional revert: instead, use
   * `AuthorizerAdaptorEntrypoint.performAction`.
   * @param target - Address of the contract to be called
   * @param data - Calldata to be sent to the target contract
   * @return The bytes encoded return value from the performed function call
   */
  function performAction(
    address target,
    bytes calldata data
  ) external payable returns (bytes memory) {
    // WARNING: the following line contains a critical bug that allows the caller to trick this contract into
    // checking for an incorrect permission.
    // We unconditionally read memory slot 100, which is where the first four bytes of `data` will reside (i.e. the
    // function selector) given a standard packed ABI encoding. Both the Solidity compiler and clients such as
    // ethers.js will do the ABI encoding in such a way that the selector is actually on slot 100, since this is the
    // way that minimizes gas costs, but it is *not* the only valid way to ABI encode.
    // In particular, it is possible to choose a larger offset and place `data` much further away in calldata. Under
    // those conditions, slot 100 will *not* contain the selector, but it can instead be any arbitrary value. This
    // means that the AuthorizerAdaptor can be made to check for the permission of any arbitrary selector,
    // regardless of the action encoded in `data`.
    //
    // In other words, an account that has permission to execute *any* action via the Adaptor can actually execute
    // *all* of them: there's no permission granularity.
    // Note that actually performing this exploit requires the ability to manually craft calldata: as such,
    // Solidity contracts that call into the Adaptor and create the call via the `abi.encode` function are safe to
    // use since they will always use the standard encoding.
    //
    // To work around this issue, the `TimelockAuthorizer` contract contains a special condition that will check
    // when it is being called by the `AuthorizerAdaptor`, and behave differently when that happens. See the
    // `TimelockAuthorizer.canPerform` and `AuthorizerAdaptorEntrypoint.performAction` functions for more
    // information.
    //
    // All comments below are part of the original source code, and as noted above some of them are incorrect. They
    // are kept for historical reasons.

    bytes4 selector;

    // We want to check that the caller is authorized to call the function on the target rather than this function.
    // We must then pull the function selector from `data` rather than `msg.sig`. The most effective way to do this
    // is via assembly.
    // Note that if `data` is empty this will return an empty function signature (0x00000000)

    // solhint-disable-next-line no-inline-assembly
    assembly {
      // The function selector encoded in `data` has an offset relative to the start of msg.data of:
      // - 4 bytes due to the function selector for `performAction`
      // - 3 words (3 * 32 = 96 bytes) for `target` and the length and offset of `data`
      // 96 + 4 = 100 bytes
      selector := calldataload(100)
    }

    // NOTE: The `TimelockAuthorizer` special cases the `AuthorizerAdaptor` calling into it, so that the action ID
    // and `target` values are completely ignored. The following check will only pass if the caller is the
    // `AuthorizerAdaptorEntrypoint`, which will have already checked for permissions correctly.
    _require(
      _canPerform(getActionId(selector), msg.sender, target),
      Errors.SENDER_NOT_ALLOWED
    );

    // We don't check that `target` is a contract so all calls to an EOA will succeed.
    return target.functionCallWithValue(data, msg.value);
  }
}
