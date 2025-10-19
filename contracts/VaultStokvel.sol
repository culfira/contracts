// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICulfiraToken.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultManager.sol";
import "./libraries/VaultLib.sol";
import "./libraries/MathLib.sol";
import "./utils/Constants.sol";
import "./utils/Errors.sol";

contract VaultStokvel is IVault, ReentrancyGuard, Ownable {
    using VaultLib for *;
    using MathLib for uint256;

    // --- State ---
    ICulfiraToken public immutable culToken;
    IVaultManager public immutable manager;

    uint256 private _currentRound;
    uint256 private _totalMembers;
    uint256 private _totalStaked;

    mapping(uint256 => Round) private _rounds;
    mapping(address => Member) private _members;
    mapping(address => uint256) private _memberIndex;
    mapping(address => Debt) private _debts;
    mapping(address => bool) private _marginCallActive;
    mapping(address => uint256) private _marginCallTimestamp;

    address[] private _memberList;

    // --- Modifiers ---
    modifier onlyManager() {
        if (msg.sender != address(manager)) revert Errors.Unauthorized();
        _;
    }

    modifier onlyActiveMember() {
        if (!_members[msg.sender].isActive) revert Errors.NotActiveMember();
        _;
    }

    // --- Constructor ---
    constructor(address culToken_, address manager_) Ownable(msg.sender) {
        if (culToken_ == address(0) || manager_ == address(0)) {
            revert Errors.InvalidAddress();
        }

        culToken = ICulfiraToken(culToken_);
        manager = IVaultManager(manager_);
        _currentRound = 1;
    }

    // --- Core Functions ---
    function joinVault(uint256 amount) external nonReentrant {
        if (amount < Constants.MIN_STAKE) revert Errors.BelowMinimumStake();
        if (_members[msg.sender].isActive) revert Errors.AlreadyMember();

        Round storage round = _rounds[_currentRound];
        if (round.state != RoundState.DEPOSIT && _currentRound != 1) {
            revert Errors.RoundNotInDepositPhase();
        }

        // Transfer and lock
        if (!culToken.transferFrom(msg.sender, address(this), amount)) {
            revert Errors.TransferFailed();
        }
        culToken.lock(msg.sender, amount);

        // Register member
        _members[msg.sender] = Member({
            stakedAmount: amount,
            position: _totalMembers,
            joinedRound: _currentRound,
            hasReceivedPayout: false,
            isActive: true
        });

        _memberIndex[msg.sender] = _memberList.length;
        _memberList.push(msg.sender);

        _totalMembers++;
        _totalStaked += amount;

        emit MemberJoined(msg.sender, amount, _totalMembers - 1);
    }

    function startRound() external onlyManager {
        _startRoundInternal(Constants.ROUND_DURATION);
    }

    function startRoundWithDuration(
        uint256 customDuration
    ) external onlyManager {
        if (customDuration == 0 || customDuration > 365 days) {
            revert Errors.InvalidAmount();
        }
        _startRoundInternal(customDuration);
    }

    function _startRoundInternal(uint256 duration) internal {
        if (_totalMembers == 0) revert Errors.NoMembers();

        if (_currentRound > 1) {
            Round storage prevRound = _rounds[_currentRound - 1];
            if (prevRound.state != RoundState.COMPLETED) {
                revert Errors.PreviousRoundNotCompleted();
            }
        }

        address recipient = _getNextRecipient();

        _rounds[_currentRound] = Round({
            id: _currentRound,
            totalStaked: _totalStaked,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            cycleDuration: duration,
            recipient: recipient,
            state: RoundState.ACTIVE
        });

        emit RoundStarted(_currentRound, _totalStaked, duration);
    }

    function claimRoundCUL() external nonReentrant {
        Round storage round = _rounds[_currentRound];

        if (round.state != RoundState.ACTIVE) revert Errors.RoundNotActive();
        if (round.recipient != msg.sender) revert Errors.NotYourTurn();
        if (_debts[msg.sender].isActive) revert Errors.AlreadyClaimed();

        uint256 totalCUL = round.totalStaked;

        // Unlock and transfer
        culToken.unlock(msg.sender, _members[msg.sender].stakedAmount);
        if (!culToken.transfer(msg.sender, totalCUL)) {
            revert Errors.TransferFailed();
        }

        // Record debt
        _debts[msg.sender] = Debt({
            amount: totalCUL,
            initialValue: totalCUL,
            deadline: round.endTime,
            isActive: true
        });

        round.state = RoundState.PAYOUT;

        emit PayoutClaimed(msg.sender, totalCUL, _currentRound);
    }

    function repayDebt() external nonReentrant {
        Debt storage debt = _debts[msg.sender];
        if (!debt.isActive) revert Errors.NoActiveDebt();

        uint256 debtAmount = debt.amount;

        // Transfer back
        if (!culToken.transferFrom(msg.sender, address(this), debtAmount)) {
            revert Errors.TransferFailed();
        }
        culToken.lock(msg.sender, _members[msg.sender].stakedAmount);

        // Clear debt
        debt.isActive = false;
        debt.amount = 0;

        _members[msg.sender].hasReceivedPayout = true;
        _marginCallActive[msg.sender] = false;

        emit DebtRepaid(msg.sender, debtAmount, _currentRound);
    }

    function completeRound() external onlyManager {
        Round storage round = _rounds[_currentRound];

        if (round.state != RoundState.PAYOUT) revert Errors.RoundNotInPayout();
        if (_debts[round.recipient].isActive) revert Errors.MustRepayDebt();

        round.state = RoundState.COMPLETED;
        _currentRound++;

        emit RoundCompleted(_currentRound - 1);
    }

    // --- Risk Management ---
    function checkHealthFactor(address user) public view returns (uint256) {
        Debt memory debt = _debts[user];
        if (!debt.isActive) return type(uint256).max;

        uint256 currentBalance = culToken.balanceOf(user);
        return
            VaultLib.calculateHealthFactor(currentBalance, debt.initialValue);
    }

    function enforceHealthFactor(address user) external {
        if (!_debts[user].isActive) revert Errors.NoActiveDebt();

        VaultLib.HealthFactorResult memory result = VaultLib.assessHealthFactor(
            checkHealthFactor(user)
        );

        if (result.isCritical) {
            if (!_marginCallActive[user]) {
                _marginCallActive[user] = true;
                _marginCallTimestamp[user] = block.timestamp;
                emit MarginCall(user, result.healthFactor, "CRITICAL");
            }
        } else if (result.isWarning) {
            emit MarginCall(user, result.healthFactor, "WARNING");
        }
    }

    function liquidate(address user) external nonReentrant {
        if (!_marginCallActive[user]) revert Errors.NoMarginCall();
        if (
            block.timestamp <=
            _marginCallTimestamp[user] + Constants.GRACE_PERIOD
        ) {
            revert Errors.GracePeriodActive();
        }
        if (checkHealthFactor(user) >= Constants.HEALTH_FACTOR_THRESHOLD) {
            revert Errors.HealthFactorOK();
        }

        Member storage member = _members[user];
        uint256 penalty = VaultLib.calculatePenalty(
            member.stakedAmount,
            Constants.LIQUIDATION_PENALTY
        );

        // Slash stake
        member.stakedAmount -= penalty;
        _totalStaked -= penalty;

        // Transfer penalty
        culToken.unlock(user, penalty);
        if (!culToken.transfer(address(manager), penalty)) {
            revert Errors.TransferFailed();
        }

        uint256 deficit = VaultLib.calculateDeficit(
            _debts[user].initialValue,
            culToken.balanceOf(user)
        );

        emit Liquidated(user, deficit, penalty);
    }

    function topUpCUL(uint256 amount) external {
        if (!_marginCallActive[msg.sender]) revert Errors.NoMarginCall();

        if (!culToken.transferFrom(msg.sender, address(this), amount)) {
            revert Errors.TransferFailed();
        }

        if (
            checkHealthFactor(msg.sender) >= Constants.HEALTH_FACTOR_THRESHOLD
        ) {
            _marginCallActive[msg.sender] = false;
        }
    }

    // --- Exit Functions ---
    function exitVault() external nonReentrant onlyActiveMember {
        if (_debts[msg.sender].isActive) revert Errors.MustRepayDebt();
        if (!_members[msg.sender].hasReceivedPayout) {
            revert Errors.MustCompleteOneCycle();
        }

        Member storage member = _members[msg.sender];
        uint256 stakeAmount = member.stakedAmount;

        // Unlock and transfer
        culToken.unlock(msg.sender, stakeAmount);
        if (!culToken.transfer(msg.sender, stakeAmount)) {
            revert Errors.TransferFailed();
        }

        // Update state
        member.isActive = false;
        _totalStaked -= stakeAmount;

        emit MemberExited(msg.sender, stakeAmount);
    }

    // --- Internal Functions ---
    function _getNextRecipient() internal view returns (address) {
        if (_totalMembers == 0) return address(0);

        for (uint256 i = 0; i < _memberList.length; i++) {
            address member = _memberList[i];
            if (
                _members[member].isActive && !_members[member].hasReceivedPayout
            ) {
                return member;
            }
        }

        // Reset cycle - find first active member
        for (uint256 i = 0; i < _memberList.length; i++) {
            address member = _memberList[i];
            if (_members[member].isActive) {
                return member;
            }
        }

        return address(0);
    }

    // --- View Functions ---
    function getNextRecipient() external view returns (address) {
        return _getNextRecipient();
    }

    function getCurrentRound() external view returns (Round memory) {
        return _rounds[_currentRound];
    }

    function getRoundInfo(
        uint256 roundId
    ) external view returns (Round memory) {
        return _rounds[roundId];
    }

    function getMemberInfo(address user) external view returns (Member memory) {
        return _members[user];
    }

    function getDebtInfo(address user) external view returns (Debt memory) {
        return _debts[user];
    }

    function totalMembers() external view returns (uint256) {
        return _totalMembers;
    }

    function totalStaked() external view returns (uint256) {
        return _totalStaked;
    }

    function currentRound() external view returns (uint256) {
        return _currentRound;
    }
}
