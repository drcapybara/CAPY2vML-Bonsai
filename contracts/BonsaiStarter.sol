// Copyright 2023 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

import {IBonsaiRelay} from "bonsai/IBonsaiRelay.sol";
import {BonsaiCallbackReceiver} from "bonsai/BonsaiCallbackReceiver.sol";

/// @title A starter application using Bonsai through the on-chain relay.
/// @dev This contract demonstrates one pattern for offloading the computation of an expensive
//       or difficult to implement function to a RISC Zero guest running on Bonsai.
contract BonsaiStarter is BonsaiCallbackReceiver {
    /// @notice Cache of the results calculated by our guest program in Bonsai.
    /// @dev Using a cache is one way to handle the callback from Bonsai. Upon callback, the
    ///      information from the journal is stored in the cache for later use by the contract.
    mapping(uint256 => uint256) public predictCache;

    /// @notice Image ID of the only zkVM binary to accept callbacks from.
    bytes32 public immutable predImageId;

    /// @notice Gas limit set on the callback from Bonsai.
    /// @dev Should be set to the maximum amount of gas your callback might reasonably consume.
    uint64 private constant BONSAI_CALLBACK_GAS_LIMIT = 100000;

    address public owner;

    /// @notice Initialize the contract, binding it to a specified Bonsai relay and RISC Zero guest image.
    constructor(IBonsaiRelay bonsaiRelay, bytes32 _predImageId) BonsaiCallbackReceiver(bonsaiRelay) {
        predImageId = _predImageId;
        owner = msg.sender;

    }

    event CalculatePredictCallback(uint256 indexed n, uint256 result);

    /// @notice Returns nth number in the Predict sequence.
    /// @dev The sequence is defined as 1, 1, 2, 3, 5 ... with predict(0) == 1.
    ///      Only precomputed results can be returned. Call calculate_predict(n) to precompute.
    function predict(uint256 n) external view returns (uint256) {
        uint256 result = predictCache[n];
        require(result != 0, "value not available in cache");
        return result;
    }

    /// @notice Callback function logic for processing verified journals from Bonsai.
    function storeResult(uint256 n, uint256 result) external onlyBonsaiCallback(predImageId) {
        emit CalculatePredictCallback(n, result);
        predictCache[n] = result;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /// @notice Sends a request to Bonsai to perform inference on a hard-coded model, assuming
    /// fee is paid.
    /// @dev This function sends the request to Bonsai through the on-chain relay.
    ///      The request will trigger Bonsai to run the specified RISC Zero guest program with
    ///      the given input and asynchronously return the verified results via the callback below.
    function calculatePredict(uint256 n) external payable {
        
        require(msg.value == 0.01 ether, "Please send exactly 0.01 Ether");

        bonsaiRelay.requestCallback(
            predImageId, abi.encode(n), address(this), this.storeResult.selector, BONSAI_CALLBACK_GAS_LIMIT
        );
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

}
