import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

function createElement(tagName) {
  return {
    tagName,
    children: [],
    appendChild(child) {
      this.children.push(child)
      return child
    },
    insertCell() {
      const cell = createElement('td')
      this.children.push(cell)
      return cell
    },
    addEventListener() {},
  }
}

describe('Browser rendering security', function () {
  it('Renders todo fields as text and preserves multiline titles', function () {
    const table = createElement('table')
    const context = {
      document: {
        createElement,
        querySelector() {
          return table
        },
      },
    }
    const source = readFileSync(new URL('../public/js/todo-client.js', import.meta.url), 'utf8')
    vm.runInNewContext(source, context)

    const payload = '<img src=x onerror=alert(1)>'
    const title = `${payload}\nsecond line`
    context.addTodoToTable({ _id: payload, title, type: payload, done: false })

    const row = table.children[0]
    assert.equal(Object.hasOwn(row, 'innerHTML'), false)
    assert.equal(row.children[1].children[0].textContent, title)
    assert.equal(row.children[2].textContent, payload)
  })

  it('Renders upstream weather descriptions as text', function () {
    const weatherList = createElement('ul')
    const elements = {
      error: createElement('div'),
      weatherIcon: createElement('div'),
      location: createElement('span'),
      'weather-list': weatherList,
    }
    for (const element of Object.values(elements)) {
      element.classList = { add() {} }
    }

    const context = {
      document: {
        createElement,
        getElementById(id) {
          return elements[id]
        },
      },
      navigator: {
        geolocation: {
          getCurrentPosition() {},
        },
      },
    }
    const source = readFileSync(new URL('../public/js/weather.js', import.meta.url), 'utf8')
    vm.runInNewContext(source, context)

    const payload = '<img src=x onerror=alert(1)>'
    context.addWeatherDetails(payload)

    assert.equal(Object.hasOwn(weatherList.children[0], 'innerHTML'), false)
    assert.equal(weatherList.children[0].textContent, payload)
  })
})
