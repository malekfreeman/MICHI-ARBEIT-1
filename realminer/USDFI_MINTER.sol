/**
 * @title USDFI MINTER
 * @dev USDFI_MINTER contract
 *
 * @author - <MIDGARD TRUST>
 * for the Midgard Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

import "./SafeERC20.sol";
import "./IUSDFI.sol";
import "./Pausable.sol";
import "./IRouter2.sol";
import "./IReferrals.sol";
import "./ReentrancyGuard.sol";

pragma solidity 0.6.12;

contract USDFI_MINTER is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IReferrals public referrals;

    address[] public wantToUSDFI = [
        0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
        0x55d398326f99059fF775485246999027B3197955
    ];

    address internal mintToken = 0x8F3e0fc147B771eC4aAd4F73F1c9A23914C598A9; //USDFI

    address public unirouter = 0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8;

    address public receiverAddress = 0xC9690De835d64e3073c7B6e214089a477614aE57;

    uint256 public minReferralAmount = 100000000000000000000;

    // Mint new USDFI about the way "wantToUSDFI"
    function mintNewUSDFI(
        uint256 _amount,
        uint256 _min,
        address _sponsor
    ) public whenNotPaused nonReentrant {
        _preCheck(_amount);

        _createNewUSDFI(_amount, _min);

        _setReferral(_amount, _sponsor);
    }

    // Pre Check the sender has enough tokens and has given enough permission.
    function _preCheck(uint256 _amount) public view {
        require(
            IERC20(wantToUSDFI[0]).balanceOf(msg.sender) >= _amount,
            "You need more payment Coins"
        );

        require(
            IERC20(wantToUSDFI[0]).allowance(msg.sender, address(this)) >=
                _amount,
            "You need more allowance"
        );
    }

    // Create new Tokens by burning "want" Token
    function _createNewUSDFI(uint256 _amount, uint256 _min) private {
        IERC20(wantToUSDFI[0]).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        uint256 receivedPaymentTokenTokens = IERC20(wantToUSDFI[0]).balanceOf(
            address(this)
        );

        IRouter2(unirouter)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                receivedPaymentTokenTokens,
                _min,
                wantToUSDFI,
                address(this),
                now
            );

        uint256 receivedWantTokens = IERC20(wantToUSDFI[1]).balanceOf(
            address(this)
        );

        IERC20(wantToUSDFI[1]).transfer(receiverAddress, receivedWantTokens);

        USDFI(mintToken).mint(msg.sender, receivedWantTokens);
    }

    // Set new Referral to database.
    function _setReferral(uint256 _amount, address _sponsor) private {
        address _sponsor1 = referrals.getSponsor(msg.sender);
        if (_amount >= minReferralAmount) {
            if (referrals.isMember(msg.sender) == false) {
                if (referrals.isMember(_sponsor) == true) {
                    referrals.addMember(msg.sender, _sponsor);
                    _sponsor1 = _sponsor;
                } else if (referrals.isMember(_sponsor) == false) {
                    _sponsor1 = referrals.membersList(0);
                }
            }
        }
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` tokens.
     *
     * This internal function is the equivalent to `approve`, and can be used to
     * set automatic allowances for certain subsystems etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address
     * - `spender` cannot be the zero address
     */
    function giveAllowances() public onlyOwner {
        IERC20(wantToUSDFI[0]).safeApprove(unirouter, uint256(0));
        IERC20(wantToUSDFI[0]).safeApprove(unirouter, uint256(-1));
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function removeAllowances() public onlyOwner {
        IERC20(wantToUSDFI[0]).safeApprove(unirouter, uint256(0));
    }

    // Set the Address who receives the payment from minting that goes.
    function setReceiverAddress(address _receiverAddress) external onlyOwner {
        receiverAddress = _receiverAddress;
    }

    // Set the minimum Amount to be allowed to enter a Referral.
    function setMinReferralAmount(uint256 _minReferralAmount)
        external
        onlyOwner
    {
        minReferralAmount = _minReferralAmount;
    }

    // Set ne external referral Contract.
    function updateReferralsContract(address _referralsContract)
        public
        onlyOwner
    {
        referrals = IReferrals(_referralsContract);
    }
}
