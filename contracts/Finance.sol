//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "hardhat/console.sol";

contract Finance is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Trade {
        uint256 index;
        uint256 periodIndex;
        uint256 traderIndex;
        uint256 time;
        uint256 amount;
        uint256 sum;
    }

    struct Period {
        uint256 index;
        uint256 startTradeIndex;
        uint256 endTradeIndex;
        uint256 total;
    }

    IERC20 public Token;
    uint256 public PERIOD = 2592000;
    uint256 public Coefficient = 397; // coefficient * 1000
    uint256 public MUL = 10 ** 50;

    uint256 private StartTime = 0;

    mapping(address => uint256) public TraderMap;
    address[] public Traders;

    Trade[] public Trades;
    mapping(uint256 => uint256) private LastTrade;
    mapping(uint256 => uint256) private TraderSum;

    mapping(uint256 => Period) private Periods;
    
    uint256 private TotalSum; 
    mapping(uint256 => uint256) private RewardAmount;
    

    event RewardClaim(address, uint256);

    constructor(address token) {
        require(token != address(0), "Invalid token");
        Token = IERC20(token);
        StartTime = block.timestamp;
    }

    function setPeriod(uint256 period) public {
        require(period != 0, "Invalid period");
        PERIOD = period;
    }

    function trade(address trader, uint256 amount, uint256 timestamp) public {
        // uint256 current = block.timestamp;
        uint256 current = timestamp;

        // console.log("Trade:", trader, amount);

        if (TraderMap[trader] == 0) {
            TraderMap[trader] = Traders.length + 1;
            Traders.push(trader);
        }

        Trade memory newTrade;
        newTrade.index = Trades.length + 1;
        newTrade.periodIndex = current.sub(StartTime).div(PERIOD) + 1;
        newTrade.traderIndex = TraderMap[trader];
        newTrade.time = current;

        if (Periods[newTrade.periodIndex].index == 0) {
            Period memory newPeriod;
            newPeriod.index = newTrade.periodIndex;
            newPeriod.startTradeIndex = newTrade.index;
            newPeriod.endTradeIndex = newTrade.index;
            newPeriod.total = amount;

            Periods[newTrade.periodIndex] = newPeriod;
            TraderSum[newTrade.traderIndex] = amount;
        } else {
            Period memory newPeriod = Periods[newTrade.periodIndex];
            newPeriod.endTradeIndex = newTrade.index;
            newPeriod.total = newPeriod.total.add(amount);

            Periods[newTrade.periodIndex] = newPeriod;
            TraderSum[newTrade.traderIndex] = TraderSum[newTrade.traderIndex].add(amount);
        }

        if (Trades.length > 0)  {
            Trade memory lastTrade = Trades[Trades.length - 1];
            if (lastTrade.periodIndex + 1 >= newTrade.periodIndex) {
                TotalSum = TotalSum.add(MUL.div(Periods[newTrade.periodIndex].total).mul(newTrade.time.sub(lastTrade.time)));
            }
        }
        // console.log("Total Sum:", TotalSum);
        newTrade.sum = TraderSum[newTrade.traderIndex];
        newTrade.amount = TotalSum;

        if (LastTrade[newTrade.traderIndex] != 0) {
            Trade memory lastTrade = Trades[LastTrade[newTrade.traderIndex] - 1];
            // console.log("Last Trade", newTrade.traderIndex, LastTrade[newTrade.traderIndex]);
            // console.log("----> ", newTrade.amount, lastTrade.amount, lastTrade.sum);
            if (lastTrade.periodIndex == newTrade.periodIndex ||
                (lastTrade.periodIndex + 1 == newTrade.periodIndex && newTrade.index == Periods[newTrade.periodIndex].startTradeIndex)
            ) {
                RewardAmount[newTrade.traderIndex] = RewardAmount[newTrade.traderIndex].add((newTrade.amount.sub(lastTrade.amount)).mul(lastTrade.sum));
            } else {
                uint256 nextPeriodStartIndex = Periods[lastTrade.periodIndex + 1].startTradeIndex;
                if (nextPeriodStartIndex == 0) {
                    uint256 currentPeriodEndIndex = Periods[lastTrade.periodIndex].endTradeIndex;
                    RewardAmount[newTrade.traderIndex] = RewardAmount[newTrade.traderIndex].add((Trades[currentPeriodEndIndex - 1].amount.sub(lastTrade.amount)).mul(lastTrade.sum));
                } else {
                    RewardAmount[newTrade.traderIndex] = RewardAmount[newTrade.traderIndex].add((Trades[nextPeriodStartIndex - 1].amount.sub(lastTrade.amount)).mul(lastTrade.sum));
                }
            }
        }

        // console.log(newTrade.periodIndex, newTrade.traderIndex, LastTrade[newTrade.traderIndex]);
        // console.log(RewardAmount[newTrade.traderIndex]);

        LastTrade[newTrade.traderIndex] = newTrade.index;
        Trades.push(newTrade);
    }

    function claim(address account) public {
        require(account != address(0), "Invalid address");
        if (TraderMap[account] == 0) {
            TraderMap[account] = Traders.length + 1;
            Traders.push(account);
        }

        uint256 traderIndex = TraderMap[account];

        if (LastTrade[traderIndex] != 0) {
            Trade memory lastTrade = Trades[LastTrade[traderIndex] - 1];
            uint256 nextPeriodStartIndex = Periods[lastTrade.periodIndex + 1].startTradeIndex;
            if (nextPeriodStartIndex == 0) {
                uint256 currentPeriodEndIndex = Periods[lastTrade.periodIndex].endTradeIndex;
                RewardAmount[traderIndex] = RewardAmount[traderIndex].add((Trades[currentPeriodEndIndex - 1].amount.sub(lastTrade.amount)).mul(lastTrade.sum));
            } else {
                RewardAmount[traderIndex] = RewardAmount[traderIndex].add((Trades[nextPeriodStartIndex - 1].amount.sub(lastTrade.amount)).mul(lastTrade.sum));
            }
        }

        uint256 amount = RewardAmount[traderIndex].mul(Coefficient).div(1000).div(MUL);

        // console.log(account, amount);
        require(amount <= Token.balanceOf(address(this)), "Insufficient balance");
        Token.safeTransfer(account, amount);

        RewardAmount[TraderMap[account]] = 0;
        emit RewardClaim(account, amount);
    }
}
