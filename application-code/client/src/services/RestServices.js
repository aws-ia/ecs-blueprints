// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import axios from 'axios'

let serverUrl = "http://<SERVER_ALB_URL>" //this value is replaced by AWS CodeBuild

export default {
    async getAllProducts() {
        return await axios.get(serverUrl+"/api/getAllProducts");
    },
}
