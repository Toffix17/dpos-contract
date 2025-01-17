// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/staking/IDelegatorStaking.sol";
import "./BaseStaking.sol";

abstract contract DelegatorStaking is BaseStaking, IDelegatorStaking {
  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   */
  uint256[50] private ______gap;

  /**
   * @inheritdoc IDelegatorStaking
   */
  function delegate(TConsensus consensusAddr) external payable noEmptyValue poolOfConsensusIsActive(consensusAddr) {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    _delegate(_poolDetail[__css2cid(consensusAddr)], msg.sender, msg.value);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function undelegate(TConsensus consensusAddr, uint256 amount) external nonReentrant {
    address payable delegator = payable(msg.sender);
    _undelegate(consensusAddr, _poolDetail[__css2cid(consensusAddr)], delegator, amount);
    if (!_sendRON(delegator, amount)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function bulkUndelegate(TConsensus[] calldata consensusAddrs, uint256[] calldata amounts) external nonReentrant {
    if (consensusAddrs.length == 0 || consensusAddrs.length != amounts.length) revert ErrInvalidArrays();

    address payable delegator = payable(msg.sender);
    uint256 total;

    address[] memory poolIds = __css2cidBatch(consensusAddrs);
    for (uint i = 0; i < poolIds.length;) {
      total += amounts[i];
      _undelegate(consensusAddrs[i], _poolDetail[poolIds[i]], delegator, amounts[i]);

      unchecked {
        ++i;
      }
    }

    if (!_sendRON(delegator, total)) revert ErrCannotTransferRON();
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function redelegate(TConsensus consensusAddrSrc, TConsensus consensusAddrDst, uint256 amount)
    external
    nonReentrant
    poolOfConsensusIsActive(consensusAddrDst)
  {
    address delegator = msg.sender;
    _undelegate(consensusAddrSrc, _poolDetail[__css2cid(consensusAddrSrc)], delegator, amount);
    _delegate(_poolDetail[__css2cid(consensusAddrDst)], delegator, amount);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function claimRewards(TConsensus[] calldata consensusAddrList)
    external
    override
    nonReentrant
    returns (uint256 amount)
  {
    amount = _claimRewards(msg.sender, __css2cidBatch(consensusAddrList));
    _transferRON(payable(msg.sender), amount);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function delegateRewards(TConsensus[] calldata consensusAddrList, TConsensus consensusAddrDst)
    external
    override
    nonReentrant
    poolOfConsensusIsActive(consensusAddrDst)
    returns (uint256 amount)
  {
    if (isAdminOfActivePool(msg.sender)) revert ErrAdminOfAnyActivePoolForbidden(msg.sender);
    address[] memory poolIds = __css2cidBatch(consensusAddrList);
    address poolIdDst = __css2cid(consensusAddrDst);
    return _delegateRewards(msg.sender, poolIds, poolIdDst);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function getRewards(address user, TConsensus[] calldata consensusAddrs)
    external
    view
    returns (uint256[] memory rewards_)
  {
    address[] memory poolIds = __css2cidBatch(consensusAddrs);
    return getRewardsById(user, poolIds);
  }

  /**
   * @inheritdoc IDelegatorStaking
   */
  function getRewardsById(address user, address[] memory poolIds) public view returns (uint256[] memory rewards_) {
    uint length = poolIds.length;
    uint period = IRoninValidatorSet(getContract(ContractType.VALIDATOR)).currentPeriod();
    rewards_ = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
      address poolId = poolIds[i];
      rewards_[i] = _getReward(poolId, user, period, _getStakingAmount(poolId, user));
    }
  }

  /**
   * @dev Delegates from a validator address.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   *
   * Emits the `Delegated` event.
   *
   * Note: This function does not verify the `msg.value` with the amount.
   *
   */
  function _delegate(PoolDetail storage _pool, address delegator, uint256 amount)
    internal
    anyExceptPoolAdmin(_pool, delegator)
  {
    _changeDelegatingAmount(_pool, delegator, _pool.delegatingAmount[delegator] + amount, _pool.stakingTotal + amount);
    _pool.lastDelegatingTimestamp[delegator] = block.timestamp;
    emit Delegated(delegator, _pool.pid, amount);
  }

  /**
   * @dev Undelegates from a validator address.
   *
   * Requirements:
   * - The delegator is not the pool admin.
   * - The amount is larger than 0.
   * - The delegating amount is larger than or equal to the undelegating amount.
   *
   * Emits the `Undelegated` event.
   *
   * Note: Consider transferring back the amount of RON after calling this function.
   *
   */
  function _undelegate(TConsensus consensusAddr, PoolDetail storage _pool, address delegator, uint256 amount)
    private
    anyExceptPoolAdmin(_pool, delegator)
  {
    if (amount == 0) revert ErrUndelegateZeroAmount();
    if (_pool.delegatingAmount[delegator] < amount) revert ErrInsufficientDelegatingAmount();

    IRoninValidatorSet validatorContract = IRoninValidatorSet(getContract(ContractType.VALIDATOR));
    if (
      validatorContract.isValidatorCandidate(consensusAddr)
        && validatorContract.getCandidateInfo(consensusAddr).revokingTimestamp == 0 // if candidate is not on renunciation
        && _pool.lastDelegatingTimestamp[delegator] + _cooldownSecsToUndelegate >= block.timestamp // delegator is still in cooldown
    ) revert ErrUndelegateTooEarly();

    _changeDelegatingAmount(_pool, delegator, _pool.delegatingAmount[delegator] - amount, _pool.stakingTotal - amount);
    emit Undelegated(delegator, _pool.pid, amount);
  }

  /**
   * @dev Claims rewards from the pools `_poolAddrList`.
   * Note: This function does not transfer reward to user.
   */
  function _claimRewards(address user, address[] memory poolIds) internal returns (uint256 amount) {
    uint256 period = _currentPeriod();
    for (uint256 i = 0; i < poolIds.length;) {
      amount += _claimReward(poolIds[i], user, period);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev Claims the rewards and delegates them to the consensus address.
   */
  function _delegateRewards(address user, address[] memory poolIds, address poolIdDst)
    internal
    returns (uint256 amount)
  {
    amount = _claimRewards(user, poolIds);
    _delegate(_poolDetail[poolIdDst], user, amount);
  }
}
