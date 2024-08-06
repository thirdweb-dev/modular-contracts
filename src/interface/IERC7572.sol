// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IERC7572 {

    function contractURI() external view returns (string memory);

    event ContractURIUpdated();

}
