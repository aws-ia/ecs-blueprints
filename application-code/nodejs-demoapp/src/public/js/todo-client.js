/* eslint-disable no-unused-vars */

// Global todo model
let todos = []

async function loadAllTodos() {
  const resp = await fetch('/api/todo')
  if (resp.ok) {
    todos = await resp.json()
    for (const todo of todos) {
      addTodoToTable(todo)
    }
  }
}

function clickTodoDone(id) {
  const todo = todos.find((t) => {
    return t._id == id
  })
  todo.done = !todo.done
  updateTodo(todo, (success) => {
    const todoRow = document.getElementById(id)
    const todoIcon = todoRow.querySelector('td > i')
    todoIcon.className = 'todo-check far ' + (todo.done ? 'fa-check-square' : 'fa-square')

    const todoTitle = todoRow.querySelector('td > .todo-title')
    if (todo.done) {
      todoTitle.classList.add('todo-done')
      todoTitle.setAttribute('contenteditable', 'false')
    } else {
      todoTitle.classList.remove('todo-done')
      todoTitle.setAttribute('contenteditable', 'true')
    }
  })
}

function clearForm() {
  document.getElementById('newTitle').value = ''
}

function addNewTodo() {
  const todo = {
    title: document.getElementById('newTitle').value,
    done: false,
    type: document.getElementById('newType').value,
  }

  createTodo(todo)
}

function addTodoToTable(todo) {
  const table = document.querySelector('#todo-table')
  const row = document.createElement('tr')
  const todoId = String(todo._id)
  row.id = todoId

  const checkCell = row.insertCell()
  const checkIcon = document.createElement('i')
  checkIcon.className = `todo-check far ${todo.done ? 'fa-check-square' : 'fa-square'}`
  checkIcon.addEventListener('click', () => clickTodoDone(todoId))
  checkCell.appendChild(checkIcon)

  const titleCell = row.insertCell()
  const title = document.createElement('div')
  title.contentEditable = todo.done ? 'false' : 'true'
  title.className = `todo-title ${todo.done ? 'todo-done' : ''}`
  title.textContent = String(todo.title ?? '')
  title.addEventListener('keydown', keyFilter)
  title.addEventListener('focusout', () => editTodo(todoId, title))
  titleCell.appendChild(title)

  const typeCell = row.insertCell()
  typeCell.textContent = String(todo.type ?? '')

  const deleteCell = row.insertCell()
  const deleteButton = document.createElement('button')
  deleteButton.type = 'button'
  deleteButton.className = 'btn btn-danger'
  deleteButton.addEventListener('click', () => deleteTodo(todoId))
  const deleteIcon = document.createElement('i')
  deleteIcon.className = 'fa fa-trash fa-fw'
  deleteButton.appendChild(deleteIcon)
  deleteCell.appendChild(deleteButton)

  table.appendChild(row)
}

function deleteTodoFromTable(id) {
  const e = document.getElementById(id)
  e.remove()
}

function editTodo(id, e) {
  const todo = todos.find((t) => {
    return t._id == id
  })
  todo.title = e.innerText
  updateTodo(todo, () => {})
}

async function deleteTodo(id) {
  const resp = await fetch(`/api/todo/${id}`, {
    method: 'DELETE',
  })
  if (resp.ok) {
    deleteTodoFromTable(id)
  }
}

async function createTodo(todo) {
  const resp = await fetch('/api/todo', {
    method: 'POST',
    body: JSON.stringify(todo),
    headers: { 'Content-Type': 'application/json' },
  })
  if (resp.ok) {
    const data = await resp.json()
    todo._id = data.newId
    addTodoToTable(todo)
    todos.push(todo)
  }
}

async function updateTodo(todo, callback) {
  const resp = await fetch(`/api/todo/${todo._id}`, {
    method: 'PUT',
    body: JSON.stringify(todo),
    headers: { 'Content-Type': 'application/json' },
  })
  if (resp.ok) {
    const data = await resp.json()
    callback(data)
  }
}

// This fixes the behavior of contentEditable with newlines creating divs
function keyFilter(e) {
  if (e.keyCode === 13) {
    document.execCommand('insertHTML', false, '<br/><br/>')
    e.preventDefault() // doesn't work without this
    return false
  }
}

function makeId(len) {
  let text = ''
  const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

  for (let i = 0; i < len; i++) {
    text += possible.charAt(Math.floor(Math.random() * possible.length))
  }

  return text
}
