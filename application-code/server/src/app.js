// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

const express = require('express');
const app = express();
var cors = require('cors');
const AWS = require('aws-sdk')
const port = 3001;

app.use(cors());

var swagger = require('./swagger/swagger')
app.use('/api/docs', swagger.router)

/**
* @swagger
* /status:
*   get:
*     description: Dummy endpoint used as an API health check
*     tags:
*       - Status
*     produces:
*       - application/json
*     responses:
*       200:
*         description: Retrieves a string with a health status
*/
app.get('/status', (req, res) => {
  res.send({
    message: 'AWS Demo server is up and running!'
  })
})

/**
* @swagger
* /api/getAllProducts:
*   get:
*     description: Retrieves all products available in the Dynamodb table
*     tags:
*       - Products
*     produces:
*       - application/json
*     responses:
*       200:
*         description: Retrieves a list of products
*/
app.get('/api/getAllProducts', (req, res) => {
  AB3_TABLE = "DYNAMODB_TABLE"  //DYNAMODB_TABLE value is retrieved from the generated resources created by the terraform code
    const docClient = new AWS.DynamoDB.DocumentClient();
    const params = {
      TableName: AB3_TABLE
    }

    docClient.scan(params, function(err, data) {
      if (err) {
        res.send({
          code: err.status,
          description: err.message
        });
      } else {
        var products = data.Items
        res.send({
          products
        });
      }
    });

})

// catch 404 and forward to error handler
app.use(function (req, res, next) {
    var err = new Error('Not Found')
    err.status = 404
    next(err)
  })

// error handler
app.use(function (err, req, res, next) {
    console.error(`Error catched! ${err}`)

    let error = {
        code: err.status,
        description: err.message
    }
    status: err.status || 500

    res.status(error.code).send(error)
  })

app.listen(port)
console.log('Server started on port ' + port)
