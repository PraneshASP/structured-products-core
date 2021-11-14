// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

library Constants {
    /**
     * @notice Pool, vault and token addresses
     */
    address constant CURVE_ST_ETH_POOL =
        0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;

    address constant STE_CRV_TOKEN = 0x06325440D014e39736583c165C2963BA99fAf14E;

    address constant BALANCER_VAULT =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address constant SUSHI_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    address constant SUSHI_LP_STAKING_POOL =
        0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd;

    address constant SLP_TOKEN = 0xC3D03e4F041Fd4cD388c549Ee2A29a9E5075882f;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address constant ALPHA_P_TRANCHE =
        0x2361102893CCabFb543bc55AC4cC8d6d0824A67E;

    address constant ELF_PTOKEN = 0x2361102893CCabFb543bc55AC4cC8d6d0824A67E;

    uint256 constant SECONDS_PER_DAY = 86400;

    uint256 constant FIXED_RATE = 5;
}
