// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ICreditEnforcer} from "src/interfaces/ICreditEnforcer.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ITermIssuer} from "src/interfaces/ITermIssuer.sol";
import {IPegStabilityModule} from "src/interfaces/IPegStabilityModule.sol";
import {ISavingModule} from "src/interfaces/ISavingModule.sol";

import {IAssetAdapter} from "src/adapters/AssetAdapter.sol";

contract CreditEnforcer is AccessControl, ICreditEnforcer {
    bytes32 public constant MANAGER =
        keccak256(abi.encode("credit.enforcer.manager"));

    bytes32 public constant SUPERVISOR =
        keccak256(abi.encode("credit.enforcer.supervisor"));

    struct AssetAdapter {
        bool set;
        uint256 index;
    }

    IERC20 public immutable underlying;

    ITermIssuer public immutable termIssuer;

    ISavingModule public immutable sm;
    IPegStabilityModule public immutable psm;

    uint256 public duration = 365 days;

    uint256 public assetRatioMin = type(uint256).max;
    uint256 public equityRatioMin = type(uint256).max;
    uint256 public liquidityRatioMin = type(uint256).max;

    uint256 public smDebtMax = 0;
    uint256 public psmDebtMax = 0;

    mapping(uint256 => uint256) public termDebtMax;

    address[] public assetAdapterList;
    mapping(address => AssetAdapter) public assetAdapterMap;

    constructor(
        address admin,
        IERC20 underlying_,
        ITermIssuer termIssuer_,
        IPegStabilityModule psm_,
        ISavingModule sm_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        underlying = underlying_;
        termIssuer = termIssuer_;
        psm = psm_;
        sm = sm_;
    }

    /// @notice Issue the stablecoin, check the debt cap and solvency
    /// @param amount Transfer amount of the underlying
    function mintStablecoin(uint256 amount) external returns (uint256) {
        return _mintStablecoin(msg.sender, msg.sender, amount);
    }

    /// @notice Issue the stablecoin to a recipient, check the debt cap and
    /// solvency
    /// @param amount Transfer amount of the underlying
    function mintStablecoin(
        address to,
        uint256 amount
    ) external returns (uint256) {
        return _mintStablecoin(msg.sender, to, amount);
    }

    function _mintStablecoin(
        address from,
        address to,
        uint256 amount
    ) private returns (uint256) {
        bool valid;
        string memory message;

        (valid, message) = _checkPSMDebtMax(amount);
        require(valid, message);

        psm.mint(from, to, amount);

        // (valid, message) = _checkRatios();
        // require(valid, message);

        return amount;
    }

    /// @notice Issue the savingcoin to the sender, check the debt cap and
    /// solvency
    /// @param amount Underlying amount
    function mintSavingcoin(uint256 amount) external returns (uint256) {
        return _mintSavingcoin(msg.sender, msg.sender, amount);
    }

    /// @notice Issue the savingcoin to a recipient, check the debt cap and
    /// solvency
    /// @param to Receiver address
    /// @param amount Underlying amount
    function mintSavingcoin(
        address to,
        uint256 amount
    ) external returns (uint256) {
        return _mintSavingcoin(msg.sender, to, amount);
    }

    function _mintSavingcoin(
        address from,
        address to,
        uint256 amount
    ) private returns (uint256) {
        bool valid;
        string memory message;

        (valid, message) = _checkSMDebtMax(amount);
        require(valid, message);

        sm.mint(from, to, amount);

        // (valid, message) = _checkRatios();
        // require(valid, message);

        return amount;
    }

    /// @notice Issue the term to the sender, check the debt cap and solvency
    /// @param id Term index
    /// @param amount Term mint balance
    function mintTerm(uint256 id, uint256 amount) external returns (uint256) {
        return _mintTerm(msg.sender, msg.sender, id, amount);
    }

    /// @notice Issue the term to a recipient, check the debt cap and solvency
    /// @param to Receiver address
    /// @param id Term index
    /// @param amount Term mint balance
    function mintTerm(
        address to,
        uint256 id,
        uint256 amount
    ) external returns (uint256) {
        return _mintTerm(msg.sender, to, id, amount);
    }

    function _mintTerm(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) private returns (uint256) {
        bool valid;
        string memory message;

        (valid, message) = _checkTermDebtMax(id, amount);
        require(valid, message);

        uint256 cost = termIssuer.mint(from, to, id, amount);

        (valid, message) = _checkRatios();
        require(valid, message);

        return cost;
    }

    /// @notice Move capital (underlying) to a fund and check solvency
    /// @param index Fund index
    /// @param amount Underlying amount
    function allocate(
        uint256 index,
        uint256 amount
    ) external onlyRole(MANAGER) {
        require(
            _assetAdapterLength() > index,
            "CE: Asset Adapter index out of bounds"
        );

        address assetAdapterAddress = assetAdapterList[index];

        psm.withdraw(amount);

        underlying.approve(assetAdapterAddress, amount);
        IAssetAdapter(assetAdapterAddress).allocate(amount);
    }

    /// @notice Move capital (underlying) from a fund and check solvency
    /// @param index Fund index
    /// @param amount Underlying amount
    function withdraw(
        uint256 index,
        uint256 amount
    ) external onlyRole(MANAGER) {
        require(
            _assetAdapterLength() > index,
            "CE: Asset Adapter index out of bounds"
        );

        address assetAdapterAddress = assetAdapterList[index];
        IAssetAdapter(assetAdapterAddress).withdraw(amount);

        underlying.approve(address(psm), amount);
        psm.allocate(amount);
    }

    /// @notice Submit a deposit order on a fund and check solvency
    /// @param index Fund index
    /// @param amount Underlying amount
    function deposit(uint256 index, uint256 amount) external onlyRole(MANAGER) {
        require(
            _assetAdapterLength() > index,
            "CE: Asset Adapter index out of bounds"
        );

        bool valid;
        string memory message;

        address assetAdapterAddress = assetAdapterList[index];
        IAssetAdapter(assetAdapterAddress).deposit(amount);

        (valid, message) = _checkRatios();
        require(valid, message);
    }

    /// @notice Submit a redemption order on a fund and check solvency
    /// @param index Fund index
    /// @param amount Underlying amount
    function redeem(uint256 index, uint256 amount) external onlyRole(MANAGER) {
        require(
            _assetAdapterLength() > index,
            "CE: Asset Adapter index out of bounds"
        );

        bool valid;
        string memory message;

        address assetAdapterAddress = assetAdapterList[index];
        IAssetAdapter(assetAdapterAddress).redeem(amount);

        (valid, message) = _checkRatios();
        require(valid, message);
    }

    /// @notice Check PSM's max debt status if specified amount of underlying stablecoin was swapped
    /// @param amount amount of underlying stablecoin
    /// @return valid If swapping with the amount is valid in terms of PSM debt
    /// @return message error message
    function checkPSMDebtMax(
        uint256 amount
    ) external view returns (bool, string memory) {
        return _checkPSMDebtMax(amount);
    }

    function _checkPSMDebtMax(
        uint256 amount
    ) private view returns (bool, string memory) {
        if (amount + psm.underlyingBalance() > psmDebtMax) {
            return (false, "CE: amount exceeds PSM debt max");
        }

        return (true, "");
    }

    /// @notice Check SM's max debt status if specifie amount of underlying stablecoin was swapped
    /// @param amount amount of underlying stablecoin
    /// @return valid If swapping with the amount is valid in terms of SM debt
    /// @return message error message
    function checkSMDebtMax(
        uint256 amount
    ) external view returns (bool, string memory) {
        return _checkSMDebtMax(amount);
    }

    function _checkSMDebtMax(
        uint256 amount
    ) private view returns (bool, string memory) {
        if (amount + sm.totalDebt() > smDebtMax) {
            return (false, "CE: amount exceeds SM debt max");
        }

        return (true, "");
    }

    /// @notice Check specific Term's max debt status if specifie amount of that term was minted
    /// @param id Term identifier
    /// @param amount term amount
    /// @return valid If minting the term with the amount is valid in terms of it's max debt
    /// @return message error message
    function checkTermDebtMax(
        uint256 id,
        uint256 amount
    ) external view returns (bool, string memory) {
        return _checkTermDebtMax(id, amount);
    }

    function _checkTermDebtMax(
        uint256 id,
        uint256 amount
    ) private view returns (bool, string memory) {
        if (amount + termIssuer.totalSupply(id) > _getTermDebtMax(id)) {
            return (false, "CE: amount exceeds term minter debt max");
        }

        return (true, "");
    }

    /// @notice Check balance sheet ratios
    /// @return valid If ratios are valid
    /// @return message error message
    function checkRatios() external view returns (bool, string memory) {
        return _checkRatios();
    }

    function _checkRatios() private view returns (bool, string memory) {
        if (assetRatioMin > _assetRatio(0)) {
            return (false, "CE: invalid asset ratio");
        }

        if (equityRatioMin > _equityRatio(0)) {
            return (false, "CE: invalid equity ratio");
        }

        if (liquidityRatioMin > _liquidityRatio(duration)) {
            return (false, "CE: invalid liquidity ratio");
        }

        return (true, "");
    }

    /// @notice Get asset ratio
    /// @return ratio asset ratio
    function assetRatio() external view returns (uint256) {
        return _assetRatio(0);
    }

    function _assetRatio(uint256) private view returns (uint256) {
        uint256 assets_ = _assets();
        uint256 liabilities_ = _liabilities();

        if (assets_ == 0) return 0;
        if (liabilities_ == 0) return type(uint256).max;

        return (assets_ * 1e6) / liabilities_;
    }

    /// @notice Get equity ratio
    /// @return ratio equity ratio
    function equityRatio() external view returns (uint256) {
        return _equityRatio(0);
    }

    function _equityRatio(uint256) private view returns (uint256) {
        uint256 equity_ = _equity();
        uint256 riskWeightedAssets_ = _riskWeightedAssets();

        if (equity_ == 0) return 0;
        if (riskWeightedAssets_ == 0) return type(uint256).max;

        return (equity_ * 1e6) / riskWeightedAssets_;
    }

    /// @notice Get liquidity ratio
    /// @return ratio liquidity ratio
    function liquidityRatio() external view returns (uint256) {
        return _liquidityRatio(duration);
    }

    function _liquidityRatio(uint256 duration_) private view returns (uint256) {
        uint256 assets_ = _shortTermAssets(duration_);
        uint256 liabilities_ = _shortTermLiabilities(duration_);

        if (assets_ == 0) return 0;
        if (liabilities_ == 0) return type(uint256).max;

        return (assets_ * 1e6) / liabilities_;
    }

    /// @notice Get short term assets
    /// @return assets short term assets
    function shortTermAssets() external view returns (uint256) {
        return _shortTermAssets(duration);
    }

    function _shortTermAssets(
        uint256 _duration
    ) private view returns (uint256 stAssets) {
        uint256 length = assetAdapterList.length;

        for (uint256 i = 0; i < length; i++) {
            IAssetAdapter assetAdapter = IAssetAdapter(assetAdapterList[i]);

            if (_duration <= assetAdapter.duration()) continue;

            stAssets += assetAdapter.totalValue();
        }

        stAssets += psm.totalValue();
    }

    /// @notice Get extended assets
    /// @return assets extended assets
    function extendedAssets() external view returns (uint256) {
        return _extendedAssets(duration);
    }

    function _extendedAssets(
        uint256 _duration
    ) private view returns (uint256 eAssets) {
        uint256 length = assetAdapterList.length;

        for (uint256 i = 0; i < length; i++) {
            IAssetAdapter assetAdapter = IAssetAdapter(assetAdapterList[i]);

            if (_duration >= assetAdapter.duration()) continue;

            eAssets += assetAdapter.totalValue();
        }
    }

    /// @notice Get short term liabilities
    /// @return liabilities short term liabilities
    function shortTermLiabilities() external view returns (uint256) {
        return _shortTermLiabilities(duration);
    }

    function _shortTermLiabilities(
        uint256 duration_
    ) private view returns (uint256 totalLiabilities) {
        totalLiabilities = _liabilities();
        totalLiabilities -= _extendedLiabilities(duration_);

        // NOTE: The `extendedLiabilities` can not be greater than the
        // `liabilities`, but we may want to do a check here anyways, just in
        // case.
    }

    /// @notice Get extended liabilities
    /// @return liabilities extended liabilities
    function extendedLiabilities(
        uint256 duration_
    ) external view returns (uint256) {
        return _extendedLiabilities(duration_);
    }

    function _extendedLiabilities(
        uint256 duration_
    ) private view returns (uint256) {
        uint256 latestID = termIssuer.latestID();
        uint256 earliestID = termIssuer.earliestID();

        uint256 sum = 0;
        for (uint256 i = earliestID; i <= latestID; i++) {
            // MTS - BTS > duration

            // prettier-ignore
            if (termIssuer.maturityTimestamp(i) <= block.timestamp + duration_) {
                continue;
            }

            sum += termIssuer.totalSupply(i);
        }

        return sum;
    }

    /// @notice Get capital at risk
    /// @return riskWeightedAssets capital at risk
    function riskWeightedAssets() external view returns (uint256) {
        return _riskWeightedAssets();
    }

    function _riskWeightedAssets() private view returns (uint256) {
        uint256 total = 0;

        uint256 length = assetAdapterList.length;
        for (uint256 i = 0; i < length; i++) {
            total += IAssetAdapter(assetAdapterList[i]).totalRiskValue();
        }

        return total + psm.totalRiskValue();
    }

    /// @notice Get equity
    /// @return equity equity
    function equity() external view returns (uint256) {
        return _equity();
    }

    function _equity() private view returns (uint256) {
        uint256 assets_ = _assets();
        uint256 liabilities_ = _liabilities();

        return liabilities_ > assets_ ? 0 : assets_ - liabilities_;
    }

    /// @notice Get assets
    /// @return assets assets
    function assets() external view returns (uint256) {
        return _assets();
    }

    function _assets() private view returns (uint256) {
        uint256 total = 0;

        uint256 length = assetAdapterList.length;
        for (uint256 i = 0; i < length; i++) {
            total += IAssetAdapter(assetAdapterList[i]).totalValue();
        }

        return total + psm.totalValue();
    }

    /// @notice Get liabilities
    /// @return liabilities liabilities
    function liabilities() external view returns (uint256) {
        return _liabilities();
    }

    function _liabilities() private view returns (uint256) {
        return sm.rusdTotalLiability() + termIssuer.totalDebt();
    }

    /// @notice Set a length of time that determines long term and short term
    /// @param duration_ Length of time used to determine long and short term
    /// balance sheet items
    function setDuration(uint256 duration_) external onlyRole(MANAGER) {
        duration = duration_;
    }

    /// @notice Set a floor for the asset ratio
    /// @param assetRatioMin_ Value assigned to the minimum asset ratio
    function setAssetRatioMin(
        uint256 assetRatioMin_
    ) external onlyRole(MANAGER) {
        assetRatioMin = assetRatioMin_;
    }

    /// @notice Set a floor for the equity ratio
    /// @param equityRatioMin_ Value assigned to the minimum equity ratio
    function setEquityRatioMin(
        uint256 equityRatioMin_
    ) external onlyRole(MANAGER) {
        equityRatioMin = equityRatioMin_;
    }

    /// @notice Set a floor for the liquidity ratio
    /// @param liquidityRatioMin_ Value assigned to the minimum liquidity ratio
    function setLiquidityRatioMin(
        uint256 liquidityRatioMin_
    ) external onlyRole(MANAGER) {
        liquidityRatioMin = liquidityRatioMin_;
    }

    /// @notice Set a ceiling for the maximum amount of underlying stablecoin
    /// that can be held in the PSM at any given time
    /// @param psmDebtMax_ Maximum underlying balance
    function setPSMDebtMax(uint256 psmDebtMax_) external onlyRole(MANAGER) {
        psmDebtMax = psmDebtMax_;
    }

    /// @notice Set a ceiling for the maximum amount of native stablecoin
    /// that can be held in the SM at any given time
    /// @param smDebtMax_ Maximum stablecoin deposit
    function setSMDebtMax(uint256 smDebtMax_) external onlyRole(MANAGER) {
        smDebtMax = smDebtMax_;
    }

    /// @notice Set a ceiling for the maximum amount of term debt that can be
    /// issued for any given maturity
    /// @param id Term index
    /// @param amount Highest permitted debt value
    function setTermDebtMax(
        uint256 id,
        uint256 amount
    ) external onlyRole(MANAGER) {
        _setTermDebtMax(id, amount);
    }

    function _setTermDebtMax(uint256 id, uint256 amount) private {
        termDebtMax[id] = amount;
    }

    /// @notice Get the maximum amount of term debt that can be issued for specified term id
    /// @param id term identifier
    /// @return amount term's max debt
    function getTermDebtMax(uint256 id) external view returns (uint256) {
        return _getTermDebtMax(id);
    }

    function _getTermDebtMax(uint256 id) private view returns (uint256) {
        return termDebtMax[id];
    }

    function assetAdapterLength() external view returns (uint256) {
        return _assetAdapterLength();
    }

    function _assetAdapterLength() private view returns (uint256) {
        return assetAdapterList.length;
    }

    /// @notice Get a list of Asset Adapters
    /// @param startIndex Start index
    /// @param length Number of Asset Adapters to return
    /// @return list List of Asset Adapters
    function getAssetAdapterList(
        uint256 startIndex,
        uint256 length
    ) external view returns (address[] memory) {
        return _getAssetAdapterList(startIndex, length);
    }

    function _getAssetAdapterList(
        uint256 startIndex,
        uint256 length
    ) private view returns (address[] memory) {
        address[] memory list = new address[](length);

        for (uint256 i = startIndex; i < startIndex + length; i++) {
            list[i - startIndex] = assetAdapterList[i];
        }

        return list;
    }

    /// @notice Get a Asset Adapter
    /// @param adapter Asset Adapter address
    /// @return assetAdapter Asset Adapter
    function getAssetAdapter(
        address adapter
    ) external view returns (AssetAdapter memory) {
        return _getAssetAdapter(adapter);
    }

    function _getAssetAdapter(
        address adapter
    ) private view returns (AssetAdapter memory) {
        return assetAdapterMap[adapter];
    }

    /// @notice Add a Asset Adapter
    /// @param adapter Asset Adapter address
    function addAssetAdapter(address adapter) external onlyRole(SUPERVISOR) {
        AssetAdapter storage assetAdapter = assetAdapterMap[adapter];

        require(!assetAdapter.set, "CE: adapter already set");

        assetAdapterList.push(adapter);

        assetAdapter.set = true;
        assetAdapter.index = _assetAdapterLength() - 1;
    }

    /// @notice Remove a Asset Adapter
    /// @param adapter Asset Adapter address
    function removeAssetAdapter(address adapter) external onlyRole(SUPERVISOR) {
        AssetAdapter storage assetAdapter = assetAdapterMap[adapter];

        require(assetAdapter.set, "CE: adapter not set");

        uint256 lastIndex = _assetAdapterLength() - 1;
        address key = assetAdapterList[lastIndex];

        uint256 index = assetAdapter.index;

        assetAdapterList[index] = assetAdapterList[lastIndex];
        assetAdapterMap[key].index = index;

        assetAdapterList.pop();

        delete assetAdapterMap[adapter];
    }
}
