// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Signature {
    function splitSignature(
        bytes memory sig
    ) private pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(
        bytes32 message,
        bytes memory sig
    ) internal pure returns (address) {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function prefixed(bytes32 msgHash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
            );
    }

    /**
     * @dev Make sure all signatures and signers are valid
     */
    function verifySignatures(
        bytes32 msgHash,
        bytes[] memory signatures,
        address[] memory signers
    ) internal pure {
        require(signatures.length == signers.length, "INVALID_LENGTH_SIG");

        for (uint i = 0; i < signatures.length; i++) {
            bytes32 message = prefixed(msgHash);
            require(
                recoverSigner(message, signatures[i]) == signers[i],
                "INVALID_SIGNATURE"
            );
        }
    }
}
