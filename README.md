# Routine Tracker

A Ruby on Rails application for tracking personal routines through customizable forms, with powerful analytics, automated reporting, and encrypted backups.

## Overview

Routine Tracker helps you collect, organize, and analyze personal data through structured surveys and forms. Whether you're tracking pool maintenance, meditation habits, running miles, or any other routine data, this application provides the tools to capture information consistently and gain insights through metrics, alerts, and automated reports.

> **Self-Hosted Only**: This is a personal data tracking application designed for self-hosting. I don't provide a hosted service and don't want your data - you run it yourself, you control your data completely.

## Core Concepts

### Data Collection

The application uses a hierarchical structure for organizing and collecting data:

```
Forms
├── Sections
    ├── Questions
        └── Answers (stored in Responses OR standalone)
```

- **Forms**: Complete surveys with multiple sections and auto-save drafts
- **Sections**: Logical groupings of related questions that can be reused
- **Questions**: Individual data points (string, number, bool, range) that can be answered within forms OR standalone
- **Responses & Answers**: Complete form submissions or individual adhoc answers

### Analytics & Automation

- **Metrics**: Transform raw data into time-series analytics with functions (answer, sum, average, difference, count), time resolutions (5min to monthly), and gap-filling strategies (none, zero, previous, linear)
- **Alerts**: Smart monitoring with threshold-based notifications and configurable delays
- **Reports**: Automated email reports with flexible scheduling and rich HTML formatting
- **Backups**: Daily encrypted backups with manual testing capabilities

### Organization

- **Namespaces**: Hierarchical organization (e.g., `home.pool`, `fitness.running`) with sub-namespace access
- **Users**: Multi-user support with complete data isolation

## Key Features

### 🚀 **Flexible Data Entry**
- Answer questions directly for quick entry or use structured forms for comprehensive data collection
- Auto-save drafts across devices with cross-device sync
- Reusable sections across multiple forms

### 📊 **Advanced Analytics** 
- Time-series visualization with pattern recognition using wrap functionality
- Multiple gap-filling strategies for missing data
- Multi-resolution analysis from 5-minute intervals to yearly trends
- Performance caching for fast analytics with large datasets

### 🔔 **Smart Monitoring**
- Threshold-based alerts with configurable delays to avoid false alarms
- Visual status indicators in alerts and reports
- Automated email reports with flexible scheduling (daily, weekly, monthly)

### 🔒 **Data Protection**
- Daily encrypted backups sent to your email with unique encryption keys
- Complete data isolation between users
- Self-hosted with no external data sharing

## Example Use Cases

### Pool Maintenance Tracking
```
Questions:
├── Clean Filter (bool) - every 3 days
├── Check Chlorine (number) - daily
├── Pool Temperature (number) - when used
└── Vacuum Pool (bool) - weekly
```

**Analytics:**
- Alert when filter hasn't been cleaned for 3+ days
- Chlorine level trends with `fill: "previous"` to track between readings
- Weekly report showing all maintenance tasks and chemical levels

### Fitness & Wellness
```
Questions:
├── Miles Run (number) - track distance
├── Meditation (bool) - daily habit
├── Sleep Hours (number) - track rest
└── Mood (range: 1-10) - daily check-in
```

**Analytics:**
- Running total with `function: "sum"` and `width: "monthly"`
- Meditation streak tracking with `function: "count"`
- Sleep patterns with `wrap: "weekly"` to see which days you sleep best
- Alert when meditation is missed for 2+ consecutive days

### Home Management
```
Questions:
├── Water Plants (bool) - daily task
├── Check Mail (bool) - daily task
├── Water Pressure (number) - utility monitoring
└── Temperature (number) - environmental tracking
```

**Analytics:**
- Alert when plants haven't been watered for 2+ days
- Track utility readings over time with trend analysis
- Weekly report showing task completion rates

## Getting Started

### Installation

1. **Clone and setup**
   ```bash
   git clone git@github.com:josephburnett/routine.git
   cd routine
   bundle install
   rails db:create db:migrate
   ```

2. **Start the server**
   ```bash
   rails server
   # Visit http://localhost:3000
   ```

3. **Configure email (optional)**
   ```bash
   export SMTP_PASSWORD=your_smtp_password
   ```

### Quick Start

1. **Create Questions** - Navigate to Questions → New Question (e.g., "Clean Pool Filter")
2. **Answer Questions** - Use the "Answer" button for quick daily tracking
3. **Create Metrics** - Transform questions into analytics with time-series visualization
4. **Set Alerts** - Get notified when routines are missed (e.g., filter not cleaned for 3+ days)
5. **Create Reports** - Schedule automated email reports with metrics and alerts
6. **Configure Automation** - Enable backups and create reports in Settings

### Production Deployment

Deployed using [Kamal](https://kamal-deploy.org/) with background job processing, automated backups, and email delivery via SMTP.

## Technical Architecture

### Key Technologies
- **Backend**: Ruby on Rails 8 with Turbo
- **Database**: SQLite (development), PostgreSQL ready
- **Jobs**: SolidQueue for background processing
- **Visualization**: Chart.js for time-series plotting
- **Email**: ActionMailer with SMTP delivery

### Performance Features
- Smart caching for metrics and alerts with automatic invalidation
- Background processing for reports and backups
- Efficient queries optimized for time-series data
- Pagination for large datasets

### Core Models
```ruby
User → Forms → Sections → Questions → Answers
User → Metrics (analyze Questions)
User → Alerts (monitor Metrics)
User → Reports (schedule Metrics + Alerts)
```

## Contributing

This is a personal project demonstrating:
- Clean Rails architecture with flexible data modeling
- Time-series analytics and visualization
- Background job processing and email delivery
- Comprehensive caching and performance optimization
- Auto-save functionality with Turbo integration

## Acknowledgments

This entire application was developed through collaboration with **Claude**, Anthropic's AI assistant, using [Claude Code](https://claude.ai/code). Claude authored virtually all of the codebase including:

- Complete Rails application architecture and implementation
- All models, controllers, views, and database migrations  
- Time-series analytics engine with rebucketing and caching
- Background job processing and email reporting systems
- Comprehensive test suites and performance optimizations
- Deployment scripts and production configuration

The project represents a successful human-AI collaboration, where Joseph Burnett provided product vision, requirements, and occasional minor edits, while Claude handled the complete technical implementation. This demonstrates the potential for AI-assisted development in creating production-ready applications.

## License

MIT License - Copyright (c) 2025 Joseph Burnett

---

**Built for tracking the patterns that matter to you.**