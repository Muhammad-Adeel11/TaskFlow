<div align="center">

# TaskFlow

**A modern project and task management platform built with Ruby on Rails 8.**

Plan projects, assign work, track progress, sync deadlines to Google Calendar, and export professional PDF and Excel reports.

![Ruby](https://img.shields.io/badge/Ruby-4.0-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite&logoColor=white)
![Hotwire](https://img.shields.io/badge/Hotwire-Turbo%20%2B%20Stimulus-4F46E5)
![License](https://img.shields.io/badge/License-MIT-green)

</div>

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [Screenshots](#screenshots)
5. [Architecture](#architecture)
6. [Getting Started](#getting-started)
7. [Environment Variables](#environment-variables)
8. [Google Calendar Setup](#google-calendar-setup)
9. [Reports: PDF and Excel](#reports-pdf-and-excel)
10. [Roles and Permissions](#roles-and-permissions)
11. [Project Structure](#project-structure)
12. [Troubleshooting](#troubleshooting)
13. [Roadmap](#roadmap)
14. [Contributing](#contributing)
15. [License](#license)

---

## Overview

TaskFlow is a full-stack task management application for teams. It brings projects, members, tasks, deadlines and reporting into one clean interface with a glass-style design, a collapsible sidebar, dark and light themes, and list or grid views.

It was built to demonstrate a production-style Rails application: authentication, role-based authorization, search and filtering, pagination, file uploads, third-party API integration, and document generation.

## Features

### Projects and tasks
- Create, edit and delete projects with a name and description.
- Add members to a project and assign tasks to them.
- Tasks have a title, description, due date and status (**Pending**, **In progress**, **Completed**).
- Drag-and-drop task ordering (Stimulus `sortable` controller).
- Overdue detection based on the due date and status.

### Search, filter and navigation
- Advanced search and filtering with **Ransack**.
- Pagination with **Kaminari**.
- **List / Grid view switch** for projects, users and tasks, remembered per page type.
- Sidebar that peeks on hover and pins on click.

### Authentication and authorization
- Sign up, sign in and sign out with **Devise**.
- Role-based access control with **Pundit** (admin, manager, member).
- Profile editing with avatar upload (**Active Storage**).

### Calendar
- Monthly calendar view with **simple_calendar**.
- **Google Calendar integration** (OAuth 2.0): connect your Google account, sync task due dates, and see Google events inside TaskFlow.
- OAuth tokens are encrypted at rest with Active Record Encryption.

### Reports
- **PDF report** per project (Prawn): cover band, key figures, progress bar, task table, workload per member, running header and page numbers.
- **Excel report** per project (caxlsx): Summary sheet with a status chart and workload table, plus a Tasks sheet with filters, a frozen header and colour-coded statuses.
- Both exports respect the current search and filter on screen.

### Design
- "Obsidian Glass" interface with translucent surfaces and a drifting background light.
- Light and dark themes (Stimulus `theme` controller).
- Responsive layout and split-screen sign-in pages.

## Tech Stack

| Layer | Technology |
|---|---|
| Language / Framework | Ruby, Ruby on Rails 8.1 |
| Database | SQLite 3 |
| Front end | Hotwire (Turbo + Stimulus), Importmap, Propshaft, custom CSS |
| Authentication | Devise |
| Authorization | Pundit |
| Search / pagination | Ransack, Kaminari |
| File uploads | Active Storage (local disk) |
| Calendar | simple_calendar, Google Calendar API |
| PDF | Prawn, prawn-table |
| Excel | caxlsx |
| Configuration | dotenv-rails |

## Architecture

TaskFlow follows standard Rails MVC conventions with a few additional layers.

```
Browser  ->  Controllers  ->  Pundit policies (who may do this?)
                |
                +-> Models (Active Record, Ransack search)
                +-> Services  (Google Calendar sync and feed)
                +-> PDFs      (ProjectReportPdf)
                +-> Spreadsheets (ProjectReportXlsx)
                |
             Views (ERB + Turbo)  +  Stimulus controllers
```

- **Models:** `User`, `Project`, `Membership`, `Task`, `GoogleConnection`.
- **Policies:** `ProjectPolicy`, `TaskPolicy`, and others, so every action is authorized.
- **Services:** `app/services/` holds the Google Calendar client, the sync logic, and a `CalendarFeed` object that merges tasks and Google events for the calendar view.
- **Report builders:** `app/pdfs/` and `app/spreadsheets/` each contain a plain Ruby class that receives a project and its tasks and returns the file as a string. Controllers use `respond_to` with `format.pdf` and `format.xlsx`.
- **Stimulus controllers:** `sortable`, `theme`, `sidebar` and `view-switch`.

## Getting Started

### Prerequisites

- Ruby (see `.ruby-version`)
- Bundler
- SQLite 3
- Git

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>

# 2. Install gems
bundle install

# 3. Create your environment file
cp .env.example .env        # on Windows: copy .env.example .env
# then edit .env (see "Environment Variables")

# 4. Create and migrate the database
bin/rails db:create db:migrate

# 5. (Optional) load sample data
bin/rails db:seed

# 6. Start the app
bin/dev        # or: bin/rails server
```

Open <http://localhost:3000>.

### Running the tests

```bash
bin/rails test
```

## Environment Variables

Create a `.env` file in the project root. **Never commit it.** Make sure `.env` is listed in `.gitignore`.

```env
# Google Calendar (optional, see the next section)
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
# Only needed if the default redirect URI does not match
GOOGLE_REDIRECT_URI=http://localhost:3000/google_calendar/callback

# Active Record Encryption (used to encrypt Google tokens)
AR_ENCRYPTION_PRIMARY_KEY=generate-with-bin-rails-db-encryption-init
AR_ENCRYPTION_DETERMINISTIC_KEY=generate-with-bin-rails-db-encryption-init
AR_ENCRYPTION_KEY_DERIVATION_SALT=generate-with-bin-rails-db-encryption-init
```

Generate the three encryption keys with:

```bash
bin/rails db:encryption:init
```

Commit a `.env.example` file containing the same names with empty values so other developers know what to set.

## Google Calendar Setup

The Google Calendar API is free to use for this purpose.

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and create a project.
2. Go to **APIs and Services > Library** and enable the **Google Calendar API**.
3. Go to **OAuth consent screen**, choose **External**, fill in the app name and your email, and add yourself under **Test users**.
4. Go to **Credentials > Create credentials > OAuth client ID** and choose **Web application**.
5. Under **Authorized redirect URIs** add exactly:
   ```
   http://localhost:3000/google_calendar/callback
   ```
   Leave **Authorized JavaScript origins** empty, or use `http://localhost:3000` with no path.
6. Copy the client ID and secret into `.env` and restart the server.
7. In TaskFlow open **Calendar** and click **Connect Google Calendar**.

## Reports: PDF and Excel

On any project page use **Download PDF** or **Download Excel**. Both reflect the filters currently applied to the task list.

| Format | Class | Gem | Contents |
|---|---|---|---|
| PDF | `ProjectReportPdf` | prawn, prawn-table | Cover, key figures, progress bar, task table, workload per member |
| Excel | `ProjectReportXlsx` | caxlsx | Summary sheet with chart, Tasks sheet with filters and frozen header |

Adding another export follows the same pattern: a class that receives `(project, tasks)`, a `respond_to` branch in the controller, and a download link.

## Roles and Permissions

| Action | Admin | Manager | Member |
|---|:-:|:-:|:-:|
| View all projects | Yes | Yes | Own projects only |
| Create and edit projects | Yes | Yes | No |
| Manage users | Yes | No | No |
| Create and update tasks | Yes | Yes | In their projects |
| Export reports | Yes | Yes | In their projects |

> Adjust this table to match your Pundit policies.

## Project Structure

```
app/
  controllers/      Request handling
  models/           User, Project, Membership, Task, GoogleConnection
  policies/         Pundit authorization rules
  services/         Google Calendar client, sync, calendar feed
  pdfs/             ProjectReportPdf
  spreadsheets/     ProjectReportXlsx
  views/            ERB templates and layouts
  javascript/
    controllers/    Stimulus: sortable, theme, sidebar, view-switch
  assets/
    stylesheets/    application.css (design tokens, glass UI, themes)
config/
  initializers/     Active Record encryption, MIME types
  routes.rb
db/
  migrate/          Schema migrations
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `uninitialized constant ProjectReportXlsx` | Restart the server after adding `app/spreadsheets/`. |
| `Google credentials are missing` | Check `.env` is in the project root (not `.env.txt`) and restart the server. |
| `redirect_uri_mismatch` | The redirect URI in Google Cloud must match exactly, including `localhost` (not `127.0.0.1`) and the path. |
| `Invalid origin: URIs must not contain a path` | The callback URL belongs in **Authorized redirect URIs**, not in JavaScript origins. |
| Active Record encryption errors | Run `bin/rails db:encryption:init` and put the keys in `.env`. |

## Roadmap

- [ ] Email notifications for due and overdue tasks
- [ ] Task comments and file attachments
- [ ] Activity log per project
- [ ] REST / JSON API
- [ ] Docker setup and CI pipeline

## Contributing

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/my-feature`.
3. Commit your changes with a clear message.
4. Push the branch and open a pull request.

## License

Distributed under the MIT License. See `LICENSE` for details.

## Author

**<Your Name>**
GitHub: Muhammad Adeel | Email: <adeelthana122@gmail>
