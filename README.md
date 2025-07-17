# Routine Tracker

A Ruby on Rails application for tracking personal data and routines through customizable forms, with powerful analytics, automated reporting, and comprehensive backup capabilities.

## Overview

Routine Tracker helps you collect, organize, and analyze personal data through structured surveys and forms. Whether you're tracking health metrics, daily habits, mood patterns, or any other routine data, this application provides the tools to capture information consistently and gain insights through metrics, dashboards, alerts, and automated reports.

> **Self-Hosted Only**: This is a personal data tracking application designed for self-hosting. I don't provide a hosted service and don't want your data - you run it yourself, you control your data completely.

## Core Concepts

### Data Collection Hierarchy

The application uses a hierarchical structure for organizing and collecting data:

```
Forms
├── Sections
    ├── Questions
        └── Answers (stored in Responses OR standalone)
```

#### **Forms**
- Top-level containers that group related sections
- Represent complete surveys or data collection sessions
- Can be filled out multiple times to create different responses
- Support draft functionality for partial completion across sessions

#### **Sections** 
- Logical groupings of related questions within a form
- Help organize complex forms into manageable chunks
- Can be reused across multiple forms

#### **Questions**
- Individual data points you want to collect
- Can be answered within forms OR standalone for quick data entry
- Support multiple types:
  - **String**: Text input
  - **Number**: Numeric input
  - **Bool**: Yes/No checkbox
  - **Range**: Dropdown with predefined options (min/max values)
- **Flexible Usage**: Use forms for structured data collection, or answer questions directly when forms feel too heavyweight

#### **Responses & Answers**
- **Response**: A complete form submission session
- **Answer**: Individual question responses within a response OR standalone adhoc answers
- Each answer stores the actual data value based on question type
- **Adhoc Answers**: Questions can be answered directly without being part of a form response

### Analytics & Visualization

#### **Metrics**
Transform raw answer data into meaningful analytics:

- **Functions**:
  - `answer`: Direct values from question responses
  - `sum`: Add values from multiple metrics
  - `average`: Average values from multiple metrics  
  - `difference`: Subtract metrics from each other
  - `count`: Count non-zero values

- **Time Resolution**: 
  - `five_minute`, `hour`, `day`, `week`, `month`

- **Time Width**:
  - `daily`, `7_days`, `weekly`, `30_days`, `monthly`, `90_days`, `yearly`, `all_time`

- **Fill Missing Data**: Handle gaps in your data
  - `none`: Only show actual data points
  - `zero`: Fill gaps with zero values
  - `previous`: Maintain the last known value
  - `linear`: Interpolate between known values

- **Wrap Functionality**: Overlay data by time patterns
  - `none`: Standard timeline view
  - `hour`: Show patterns within an hour (0-59 minutes)
  - `day`: Show patterns within a day (00:00-23:59)  
  - `weekly`: Show patterns within a week

#### **Dashboards**
Customizable views that can display:
- Metrics with time-series visualizations
- Quick-access question answering
- Links to forms for easy data entry
- Links to other dashboards for nested navigation
- Alerts for monitoring important thresholds

#### **Alerts**
Smart monitoring system that tracks your metrics:
- **Threshold Monitoring**: Get notified when metrics cross important values
- **Flexible Conditions**: Above/below thresholds with configurable delay
- **Multiple Data Points**: Require multiple consecutive readings before activation
- **Visual Indicators**: Clear status with color coding
- **Integration**: Can be included in dashboards and reports

#### **Reports**
Automated email reports to keep you informed:
- **Scheduled Delivery**: Daily, weekly, or monthly reports
- **Flexible Timing**: Choose specific times and days for delivery
- **Content Mixing**: Combine multiple metrics and alerts in one report
- **Manual Testing**: Send reports immediately to test configuration
- **Rich Formatting**: HTML emails with charts and current values

### Data Management

#### **Backup System**
Complete data protection with encrypted backups:
- **Automated Backups**: Daily encrypted backups sent to your email
- **Manual Testing**: Send backup immediately to verify configuration
- **Encryption**: All backups are encrypted with a unique key
- **Comprehensive Data**: Includes all forms, questions, responses, metrics, and settings
- **JSON Format**: Easy to parse and restore if needed

#### **Caching & Performance**
Optimized for responsive data analysis:
- **Metric Caching**: Expensive time-series calculations are cached
- **Smart Invalidation**: Caches are cleared when underlying data changes
- **Background Jobs**: Reports and backups run in background queues
- **Efficient Queries**: Optimized database queries for large datasets

### Organization

#### **Namespaces**
Hierarchical organization system (e.g., `health.fitness`, `home.chores`) that helps categorize and filter all entities:
- **Hierarchical Access**: When in a namespace, access all sub-namespaces
- **Flexible Navigation**: Easy browsing through folder-like structure
- **Cross-Reference**: Create reports that pull from multiple related namespaces
- **Isolation**: Keep different areas of your life organized separately

#### **Users**
Multi-user support with complete data isolation - each user sees only their own forms, responses, and metrics.

## Key Features

### 🚀 **Flexible Data Entry**
- **Structured Forms**: Complete surveys with multiple sections and auto-save drafts
- **Quick Questions**: Answer individual questions directly when forms are overkill
- **Adhoc Answers**: Answer questions without creating formal responses
- **Cross-device Sync**: Continue forms on any device where you're logged in
- **Flexible Question Types**: String, number, boolean, and range inputs
- **Reusable Components**: Share sections across multiple forms

### 📊 **Advanced Analytics** 
- **Time-series Visualization**: See trends and patterns over time
- **Flexible Aggregation**: Sum, average, count, and compare metrics
- **Gap Filling**: Multiple strategies for handling missing data
- **Pattern Recognition**: Wrap functionality reveals daily/weekly patterns
- **Multi-resolution Analysis**: From 5-minute intervals to monthly trends
- **Performance Caching**: Fast analytics even with large datasets

### 📈 **Interactive Dashboards**
- **Custom Views**: Create personalized dashboards for different use cases
- **Mixed Content**: Combine metrics, quick questions, form links, and alerts
- **Real-time Updates**: See your latest data immediately
- **Nested Navigation**: Link dashboards together for complex workflows

### 🔔 **Smart Alerts**
- **Threshold Monitoring**: Get notified when metrics cross important values
- **Configurable Delays**: Require multiple data points before activation
- **Visual Status**: Clear indicators with color coding
- **Dashboard Integration**: Include alerts in your daily dashboard views

### 📧 **Automated Reports**
- **Scheduled Delivery**: Daily, weekly, or monthly automated reports
- **Flexible Scheduling**: Choose specific times and days for delivery
- **Rich Content**: HTML emails with charts, metrics, and alert status
- **Manual Testing**: Send reports immediately to verify configuration
- **Multi-content**: Combine multiple metrics and alerts in one report

### 🔒 **Data Protection**
- **Encrypted Backups**: Daily encrypted backups sent to your email
- **Manual Backup**: Send backup immediately for testing
- **Complete Data**: All forms, questions, responses, metrics, and settings
- **Self-Hosted**: Your data never leaves your infrastructure
- **Unique Encryption**: Each user has their own encryption key

### ⚡ **Performance & Reliability**
- **Background Processing**: Reports and backups run in background queues
- **Smart Caching**: Expensive calculations are cached and invalidated intelligently
- **Efficient Queries**: Optimized for large datasets and complex analytics
- **Fault Tolerance**: Graceful handling of errors with user feedback

## Example Use Cases

### Health & Fitness Tracking
```
Form: "Daily Health Check"
├── Section: "Physical Metrics"
│   ├── Weight (number)
│   ├── Sleep Hours (number)
│   └── Exercise (bool)
└── Section: "Mental Wellness"
    ├── Mood (range: 1-10)
    ├── Stress Level (range: 1-5)
    └── Meditation (bool)
```

**Advanced Analytics:**
- Average daily weight with `fill: "linear"` to smooth out gaps
- Sleep patterns with `resolution: "day"`, `wrap: "weekly"` to see which days you sleep best
- Exercise consistency with `function: "count"` to track workout frequency
- Mood trends with `fill: "previous"` to maintain baseline between entries

**Alerts & Reports:**
- Alert when weight deviates more than 5 lbs from target
- Weekly report showing all health metrics and trends
- Daily backup of all health data

### Home Management
```
Form: "Household Tasks"
├── Section: "Maintenance"
│   ├── Cleaned Kitchen (bool)
│   ├── Watered Plants (bool)
│   └── Checked Mail (bool)
└── Section: "Utilities"
    ├── Water Pressure (range: 1-10)
    ├── Temperature (number)
    └── Energy Usage (number)
```

**Dashboard Setup:**
- Quick daily task checkboxes (answer questions directly)
- Water pressure trend metric with `fill: "zero"` for missing days
- Link to weekly deep-cleaning form
- Alert when water pressure drops below 5 for 2 consecutive days

**Automation:**
- Weekly report summarizing all completed tasks
- Monthly backup of household data
- Alert for maintenance tasks not completed for 3+ days

## Getting Started

### Prerequisites
- Ruby 3.x
- Rails 8.x
- SQLite (development) or PostgreSQL (production)
- SMTP server for email delivery (reports and backups)

### Installation

1. **Clone the repository**
   ```bash
   git clone git@github.com:josephburnett/routine.git
   cd routine
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   ```

4. **Configure email (optional)**
   ```bash
   # Set environment variables for SMTP
   export SMTP_PASSWORD=your_smtp_password
   ```

5. **Start the server**
   ```bash
   rails server
   ```

6. **Visit the application**
   Open your browser to `http://localhost:3000`

### Production Deployment

The application is deployed using [Kamal](https://kamal-deploy.org/) to a local network machine (`home.local`). This setup provides a self-hosted solution accessible within your local network while maintaining complete data privacy and control.

**Key Production Features:**
- Background job processing with SolidQueue
- Automated daily backups
- Scheduled report delivery
- Performance caching
- Email delivery via SMTP

### Quick Start Guide

1. **Create your first form**
   - Navigate to Forms → New Form
   - Add sections and questions
   - Organize with namespaces (e.g., `health`, `home.maintenance`)

2. **Fill out the form**
   - Use the "Survey" link to fill out your form
   - Drafts save automatically as you type
   - Submit when complete

3. **Create metrics**
   - Navigate to Metrics → New Metric
   - Choose questions to analyze
   - Set time resolution and width
   - Configure fill strategy for missing data
   - Experiment with wrap settings for pattern analysis

4. **Set up alerts**
   - Navigate to Alerts → New Alert
   - Choose a metric to monitor
   - Set threshold and direction (above/below)
   - Configure delay to avoid false alarms

5. **Build a dashboard**
   - Navigate to Dashboards → New Dashboard
   - Add your metrics for visualization
   - Include quick-access questions for lightweight data entry
   - Add form links for structured data collection
   - Include alerts for monitoring

6. **Configure automation**
   - Go to Settings to enable backups
   - Create reports to get regular updates
   - Use manual buttons to test configuration

## Technical Architecture

### Models & Relationships

```ruby
User
├── has_many :forms
├── has_many :sections  
├── has_many :questions
├── has_many :responses
├── has_many :answers
├── has_many :metrics
├── has_many :dashboards
├── has_many :alerts
├── has_many :reports
├── has_many :form_drafts
└── has_one :user_setting

Form
├── belongs_to :user
├── has_and_belongs_to_many :sections
├── has_many :responses
└── has_many :form_drafts

Response
├── belongs_to :user
├── belongs_to :form
└── has_many :answers

Answer
├── belongs_to :question
├── belongs_to :response (optional - for adhoc answers)
└── belongs_to :user (optional - for adhoc answers)

Metric
├── belongs_to :user
├── has_many :questions (for 'answer' function)
├── has_many :child_metrics (for calculated functions)
├── belongs_to :first_metric (for 'difference' function)
└── has_one :metric_series_cache

Alert
├── belongs_to :user
├── belongs_to :metric
└── has_one :alert_status_cache

Report
├── belongs_to :user
├── has_many :alerts
└── has_many :metrics
```

### Key Technologies

- **Backend**: Ruby on Rails 8 with Turbo for seamless navigation
- **Frontend**: ERB templates with vanilla JavaScript
- **Database**: SQLite (development), PostgreSQL ready
- **Jobs**: SolidQueue for background processing
- **Visualization**: Chart.js for time-series plotting
- **Styling**: CSS custom properties with clean, responsive design
- **Email**: ActionMailer with SMTP delivery
- **Deployment**: Kamal for containerized deployment

### Performance Features

- **Caching**: Metric and alert calculations are cached with smart invalidation
- **Background Jobs**: Reports and backups run asynchronously
- **Efficient Queries**: Optimized for time-series data and large datasets
- **Pagination**: Large lists are paginated for better performance
- **Query Optimization**: Includes and joins minimize N+1 queries

### Security & Privacy

- **Data Isolation**: Complete separation between users
- **Encrypted Backups**: All backups are encrypted with unique keys
- **Self-Hosted**: No external data sharing
- **Secure Configuration**: Production-ready defaults
- **Input Validation**: Comprehensive validation on all user inputs

## Contributing

This is a personal project, but the codebase demonstrates:

- Clean Rails architecture patterns
- Flexible data modeling for user-generated content
- Time-series data handling and visualization
- Auto-save functionality with Turbo integration
- Multi-dimensional analytics (functions, time, patterns)
- Background job processing and scheduling
- Comprehensive caching strategies
- Email delivery and formatting
- Performance optimization techniques

## License

MIT License

Copyright (c) 2025 Joseph Burnett

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

**Built for tracking the patterns that matter to you.**