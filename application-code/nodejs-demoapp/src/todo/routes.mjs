//
// Optional mini todo app which uses MongoDb - only shows up when MONGO_CONNSTR is set
// ----------------------------------------------
// Ben C, July 2018
// Updated June, 2019
//

import express from 'express'
const router = express.Router()
import { MongoClient, ObjectId } from 'mongodb'

const DBNAME = process.env.TODO_MONGO_DB || 'todoDb'
const COLLECTION = 'todos'
let db

  //
  // Connect to MongoDB server
  //
;(async function () {
  if (!process.env.TODO_MONGO_CONNSTR) return
  try {
    const client = await MongoClient.connect(process.env.TODO_MONGO_CONNSTR, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    })
    db = client.db(DBNAME)
    console.log('### ✅ Enabled Todo app. Connected to MongoDB!')
  } catch (err) {
    // TODO: Track exception via AWS X-Ray
    console.log(`### 💥 ERROR! ${err.toString()}`)
  }
})()

//
// Render Todo page
//
router.get('/todo', function (req, res, next) {
  res.render('todo', {
    title: 'Node DemoApp: Todo',
  })
})

//
// Todo API: GET  - return array of all todos, probably should have pagination at some point
//
router.get('/api/todo', async function (req, res, next) {
  try {
    const result = await db.collection(COLLECTION).find({}).toArray()
    if (!result) {
      sendData(res, [])
    } else {
      sendData(res, result)
    }
  } catch (err) {
    sendError(res, err)
  }
})

//
// Todo API: POST - create or edit a new todo
//
router.post('/api/todo', async function (req, res, next) {
  const todo = req.body
  try {
    const result = await db.collection(COLLECTION).insertOne(todo)
    if (result) {
      sendData(res, {
        newId: result.insertedId,
      })
    } else {
      throw 'Error POSTing todo'
    }
  } catch (err) {
    sendError(res, err)
  }
})

//
// Todo API: PUT - update a todo
//
router.put('/api/todo/:id', async function (req, res, next) {
  const todo = req.body
  delete todo._id
  try {
    const result = await db.collection(COLLECTION).findOneAndReplace({ _id: ObjectId(req.params.id) }, todo)
    if (result) {
      sendData(res, result)
    } else {
      throw 'Error PUTing todo'
    }
  } catch (err) {
    sendError(res, err)
  }
})

//
// Todo API: DELETE - remove a todo from DB
//
router.delete('/api/todo/:id', async function (req, res, next) {
  try {
    const result = await db.collection(COLLECTION).deleteOne({ _id: ObjectId(req.params.id) })
    if (result && result.deletedCount) {
      sendData(res, { msg: `Deleted doc ${req.params.id} ok` })
    } else {
      throw 'Error DELETEing todo'
    }
  } catch (err) {
    sendError(res, err)
  }
})

//
// Helper to send standard error and track it
//
function sendError(res, err, code = 500) {
  console.dir(err)
  console.log(`### Error with API ${JSON.stringify(err)}`)
  let statuscode = code
  if (err.code > 1) {
    statuscode = err.code
  }

  // TODO: Track exception via AWS X-Ray

  res.status(statuscode).send(err)
  return
}

//
// Helper to send JSON response
//
function sendData(res, data) {
  // TODO: Track event via CloudWatch or X-Ray

  res.type('application/json')
  res.status(200).send(data)
  return
}

export default router
