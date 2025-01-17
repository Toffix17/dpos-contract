// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./ISlashDoubleSign.sol";
import "./ISlashUnavailability.sol";
import "./ICreditScore.sol";

interface ISlashIndicator is ISlashDoubleSign, ISlashUnavailability, ICreditScore { }
