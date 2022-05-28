// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

const express = require('express')
const router = express.Router()

const options = {
  swaggerDefinition: {
    info: {
      title: 'AWS Demo',
      version: '1.0.0',
      description: 'An AWS Demo for a full stack application with Amazon ECS, applying DevOps practices',
      contact: {
        email: 'burkhmar@amazon.de'
      }
    },
    tags: [
      {
        name: 'AWS Demo Endpoints',
        description: 'Enpoints descriptions'
      }
    ],
    schemes: ['http'],
    host: '<SERVER_ALB_URL>',
    basePath: '/'
  },
  apis: [
    './src/app.js',
  ],
}

const swaggerJSDoc = require('swagger-jsdoc')
const swaggerUi = require('swagger-ui-express')
const swaggerSpec = swaggerJSDoc(options)
require('swagger-model-validator')(swaggerSpec)

router.get('/json', function (req, res) {
  res.setHeader('Content-Type', 'application/json')
  res.send(swaggerSpec)
})

router.use('/', swaggerUi.serve, swaggerUi.setup(swaggerSpec))

function validateModel(name, model) {
  const responseValidation = swaggerSpec.validateModel(name, model, false, true)
  if (!responseValidation.valid) {
    console.error(responseValidation.errors)
    throw new Error(`Model doesn't match Swagger contract`)
  }
}

module.exports = {
  router,
  validateModel
}
