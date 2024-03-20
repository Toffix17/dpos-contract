// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../extensions/forwarder/Forwarder.sol";
import "../extensions/RONTransferHelper.sol";

/**
 * @title A vault contract that keeps RON, and behaves as an EOA account to interact with a target contract.
 * @dev There are three roles of interaction:
 * - Admin: top-up and withdraw RON to the vault, cannot forward call to the target.
 * - Moderator: forward all calls to the target, can top-up RON, cannot withdraw RON.
 * - Others: can top-up RON, cannot execute any other actions.
 */
contract VaultForwarder is Forwarder, RONTransferHelper {
  /// @dev Emitted when the admin withdraws all RON from the forwarder contract.
  event ForwarderRONWithdrawn(address indexed recipient, uint256 value);

  constructor(address[] memory targets, address admin, address mod) Forwarder(targets, admin, mod) { }

  /**
   * @dev Withdraws all balance from the transfer to the admin.
   *
   * Requirements:
   * - Only the admin can call this method.
   */
  function withdrawAll() external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 value = address(this).balance;
    emit ForwarderRONWithdrawn(msg.sender, value);
    _transferRON(payable(msg.sender), value);
  }
}
