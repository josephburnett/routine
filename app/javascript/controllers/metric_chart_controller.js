import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    data: Array,
    metric: Object,
    chartType: String
  }

  connect() {
    console.log('MetricChart controller connected', this.element)
    console.log('Data value:', this.dataValue)
    console.log('Metric value:', this.metricValue)
    this.initializeChart()
  }

  disconnect() {
    console.log('MetricChart controller disconnecting')
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  initializeChart() {
    try {
      if (!this.hasCanvasTarget) {
        console.error('No canvas target found')
        return
      }

      if (!this.dataValue || !this.dataValue.length) {
        console.warn('No data available for chart')
        return
      }

      console.log('Initializing chart with', this.dataValue.length, 'data points')
      const ctx = this.canvasTarget.getContext('2d')
      const metric = this.metricValue

      // Destroy existing chart if it exists
      if (this.chart) {
        this.chart.destroy()
      }

      if (metric.wrap && metric.wrap !== 'none') {
        this.initializeWrappedChart(ctx, metric)
      } else {
        this.initializeRegularChart(ctx, metric)
      }
      
      console.log('Chart initialized successfully')
    } catch (error) {
      console.error('Error initializing chart:', error)
    }
  }

  initializeWrappedChart(ctx, metric) {
    if (metric.wrap === 'day') {
      // For day wrap, create data points with time-based x values
      const chartData = this.dataValue.map(([timeStr, value]) => {
        const date = new Date(timeStr)
        const minutesSinceMidnight = date.getHours() * 60 + date.getMinutes()
        return { x: minutesSinceMidnight, y: parseFloat(value) }
      })

      this.chart = new Chart(ctx, {
        type: 'scatter',
        data: {
          datasets: [{
            label: `${metric.type} Value`,
            data: chartData,
            backgroundColor: 'rgba(75, 192, 192, 0.6)',
            borderColor: 'rgb(75, 192, 192)',
            pointRadius: 3,
            showLine: false
          }]
        },
        options: {
          responsive: true,
          scales: {
            x: {
              type: 'linear',
              min: 0,
              max: 1440, // 24 * 60 minutes
              title: {
                display: true,
                text: 'Time of Day'
              },
              ticks: {
                stepSize: 60, // Show hour marks
                callback: function(value) {
                  const hours = Math.floor(value / 60)
                  return hours.toString().padStart(2, '0') + ':00'
                }
              }
            },
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Value'
              }
            }
          },
          plugins: {
            title: {
              display: true,
              text: `Metric: ${metric.function} Function (Wrapped by ${metric.wrap})`
            }
          }
        }
      })
    } else {
      // For other wrap types, use category scale
      const chartData = this.dataValue.map(([timeStr, value]) => {
        const date = new Date(timeStr)
        let formattedTime
        
        switch (metric.wrap) {
          case 'hour':
            formattedTime = date.getMinutes().toString().padStart(2, '0')
            break
          case 'weekly':
            formattedTime = `${date.getDay()}-${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
            break
          default:
            formattedTime = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
        }
        
        return { x: formattedTime, y: parseFloat(value) }
      })

      this.chart = new Chart(ctx, {
        type: 'scatter',
        data: {
          datasets: [{
            label: `${metric.type} Value`,
            data: chartData,
            backgroundColor: 'rgba(75, 192, 192, 0.6)',
            borderColor: 'rgb(75, 192, 192)',
            pointRadius: 3,
            showLine: false
          }]
        },
        options: {
          responsive: true,
          scales: {
            x: {
              type: 'category',
              title: {
                display: true,
                text: this.getWrapAxisLabel(metric.wrap)
              }
            },
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Value'
              }
            }
          },
          plugins: {
            title: {
              display: true,
              text: `Metric: ${metric.function} Function (Wrapped by ${metric.wrap})`
            }
          }
        }
      })
    }
  }

  initializeRegularChart(ctx, metric) {
    const chartData = this.dataValue.map(([timeStr, value]) => {
      const date = new Date(timeStr)
      const formattedTime = `${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
      return { x: formattedTime, y: parseFloat(value) }
    })

    this.chart = new Chart(ctx, {
      type: 'scatter',
      data: {
        datasets: [{
          label: `${metric.type} Value`,
          data: chartData,
          backgroundColor: 'rgba(75, 192, 192, 0.6)',
          borderColor: 'rgb(75, 192, 192)',
          pointRadius: 4,
          showLine: false
        }]
      },
      options: {
        responsive: true,
        scales: {
          x: {
            type: 'category',
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: 'Value'
            }
          }
        },
        plugins: {
          title: {
            display: true,
            text: `Metric: ${metric.function} Function`
          }
        }
      }
    })
  }

  getWrapAxisLabel(wrap) {
    switch (wrap) {
      case 'hour':
        return 'Minutes (0-59)'
      case 'weekly':
        return 'Day-Time (0=Sun, 6=Sat)'
      default:
        return 'Time'
    }
  }
}