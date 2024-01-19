// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ERC20Hook} from "./ERC20Hook.sol";

contract PermitHook is ERC20Hook {

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The EIP-712 typehash for the mint request struct.
    bytes32 private constant TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error PermitHookInvalidSigner();

    error PermitHookDeadlineExpired();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) private _nonces;

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function computeDomainSeparator(string memory name) public view override returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }

    /// @notice Returns all hook functions implemented by this hook contract.
    function getHooksImplemented() external pure returns (uint256 hooksImplemented) {
        hooksImplemented = PERMIT_FLAG;
    }

    /*//////////////////////////////////////////////////////////////
                            PERMIT HOOK
    //////////////////////////////////////////////////////////////*/

    function permit(
        string memory name,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        if(deadline < block.timestamp) {
            revert PermitHookDeadlineExpired();
        }

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        computeDomainSeparator(name),
                        keccak256(
                            abi.encode(
                                TYPEHASH,
                                owner,
                                spender,
                                value,
                                _nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if(recoveredAddress == address(0) || recoveredAddress != owner) {
                revert PermitHookInvalidSigner();
            }
        }
    }
}
