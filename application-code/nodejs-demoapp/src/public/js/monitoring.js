//
// Client side code used on Monitor.cshtml page
//

const DATA_INTERVAL = 3000
const MIB = 2014 * 1024
let memChart, cpuChart

// START HERE - Called on window load by Monitor.cshtml
// eslint-disable-next-line no-unused-vars
function startMonitoring() {
  // Initialize working set chart
  /* global Chart:false */
  memChart = new Chart(document.getElementById('memChart'), {
    type: 'line',

    data: {
      labels: [],
      datasets: [
        {
          label: 'Used Memory (MiBytes)',
          borderColor: 'rgba(0, 156, 220, 1.0)',
          backgroundColor: 'rgba(0, 156, 220, 0.4)',
          data: [],
        },
        {
          label: 'App Heap Used (MiBytes)',
          borderColor: 'rgba(220, 20, 20, 1.0)',
          backgroundColor: 'rgba(220, 20, 20, 0.4)',
          data: [],
        },
      ],
    },
    options: {
      elements: {
        line: {
          borderWidth: 3,
          tension: 0,
        },
      },
      scales: {
        yAxes: [
          {
            ticks: {
              beginAtZero: true,
            },
          },
        ],
      },
    },
  })

  // Initialize CPU load chart
  cpuChart = new Chart(document.getElementById('cpuChart'), {
    type: 'line',
    data: {
      labels: [],
      datasets: [
        {
          label: 'Processor Load (%)',
          data: [],
          borderColor: 'rgba(19, 185, 85, 1.0)',
          backgroundColor: 'rgba(19, 185, 85, 0.4)',
          borderWidth: 3,
          lineTension: 0,
        },
      ],
    },
    options: {
      scales: {
        yAxes: [
          {
            ticks: {
              beginAtZero: true,
            },
          },
        ],
      },
    },
  })

  // Initial data load
  getData()

  // Then fetch data every 3 seconds
  setInterval(getData, DATA_INTERVAL)
}

//
// Helper to dynamically add data to a chart
//
function addData(chart, label, data) {
  chart.data.labels.push(label)
  for (let ds = 0; ds < chart.data.datasets.length; ds++) {
    chart.data.datasets[ds].data.push(data[ds])
  }
  // chart.data.datasets.forEach((dataset) => {
  //   dataset.data.push(data);
  // });

  // Limit the charts at 30 data points, otherwise it would just fill up
  if (chart.data.datasets[0].data.length > 30) {
    chart.data.datasets[0].data.shift()
    chart.data.labels.shift()
  }
  chart.update()
}

//
// Call API to get data
//
function getData() {
  fetch('/api/monitoringdata')
    .then((response) => {
      // fetch handles errors strangely, we need to trap non-200 codes here
      if (!response.ok) {
        throw Error(response.statusText + ' ' + response.status)
      }
      return response.json()
    })
    .then((data) => {
      const d = new Date()
      const label = d.getHours() + ':' + d.getMinutes() + ':' + d.getSeconds()

      // Set max on mem chart
      memChart.options.scales.yAxes[0].ticks.max = data.memTotalBytes / MIB

      // Add results to the two charts
      addData(memChart, label, [data.memUsedBytes / MIB, data.memProcUsedBytes / MIB])
      addData(cpuChart, label, [data.cpuAppPercentage])
    })
    .catch((err) => {
      console.log(err)
    })
}
