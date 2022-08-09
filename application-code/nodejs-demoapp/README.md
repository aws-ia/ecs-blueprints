# Node.js - Demo Web Application

This is a simple Node.js web app using the Express framework and EJS templates.

The app has been designed with cloud native demos & containers in mind, in order to provide a real working application for deployment, something more than "hello-world" but with the minimum of pre-reqs. It is not intended as a complete example of a fully functioning architecture or complex software design.

Typical uses would be deployment to Kubernetes, demos of Docker, CI/CD (build pipelines are provided), deployment to cloud (AWS) monitoring, auto-scaling

The app has several basic pages accessed from the top navigation menu, some of which are only lit up when certain configuration variables are set (see 'Optional Features' below):

- **'Info'** - Will show system & runtime information, and will also display if the app is running from within a Docker container and Kubernetes.
- **'Tools'** - Some tools useful in demos, such a forcing CPU load (for autoscale demos), and error/exception pages for use with AWS X-Ray or other monitoring tool.
- **'Monitor'** - Display realtime monitoring data, showing memory usage/total and process CPU load.
- **'Weather'** - (Optional) Gets the location of the client page (with HTML5 Geolocation). The resulting location is used to fetch weather data from the [OpenWeather](https://openweathermap.org/) API
- **'Todo'** - (Optional) This is a small todo/task-list app which uses MongoDB as a database.
- **'User Account'** - (Optional) When configured with Amazon Cognito, a user login button will be enabled, and an user-account details page enabled.

![screen](https://user-images.githubusercontent.com/14982936/55620043-dfe96480-5791-11e9-9746-3b42a3a41e5f.png)
![screen](https://user-images.githubusercontent.com/14982936/55620045-dfe96480-5791-11e9-94f3-6d788ed447c1.png)
![screen](https://user-images.githubusercontent.com/14982936/58764072-d8102b80-855a-11e9-993f-21ef0344d5e0.png)

# Status

![](https://img.shields.io/github/last-commit/benc-uk/nodejs-demoapp) ![](https://img.shields.io/github/release-date/benc-uk/nodejs-demoapp) ![](https://img.shields.io/github/v/release/benc-uk/nodejs-demoapp) ![](https://img.shields.io/github/commit-activity/y/benc-uk/nodejs-demoapp)

Live instance:

[![](https://img.shields.io/website?label=Hosted%3A%20Kubernetes&up_message=online&url=https%3A%2F%2Fnodejs-demoapp.kube.benco.io%2F)](https://nodejs-demoapp.kube.benco.io/)

# Running and Testing Locally

### Pre-reqs

- Be using Linux, WSL or MacOS, with bash, make etc
- [Node.js](https://nodejs.org/en/) - for running locally, linting, running tests etc
- [Docker](https://docs.docker.com/get-docker/) - for running as a container, or building images
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) - for deployment to AWS

Clone the project to any directory where you do development work

```bash
git clone https://github.com/benc-uk/nodejs-demoapp.git
```

### Makefile

A standard GNU Make file is provided to help with running and building locally.

```txt
$ make

help                 💬 This help message
lint                 🔎 Lint & format, will not fix but sets exit code on error
lint-fix             📜 Lint & format, will try to fix errors and modify code
image                🔨 Build container image from Dockerfile
push                 📤 Push container image to registry
run                  🏃 Run locally using Node.js
deploy               🚀 Deploy to Amazon ECS
undeploy             💀 Remove from AWS
test                 🎯 Unit tests with Jest
test-report          🤡 Unit tests with Jest & Junit output
test-api             🚦 Run integration API tests, server must be running
clean                🧹 Clean up project
```

Make file variables and default values, pass these in when calling `make`, e.g. `make image IMAGE_REPO=blah/foo`

| Makefile Variable | Default                |
| ----------------- | ---------------------- |
| IMAGE_REG         | _none_                 |
| IMAGE_REPO        | nodejs-demoapp         |
| IMAGE_TAG         | latest                 |
| AWS_STACK_NAME    | demoapps               |
| AWS_REGION        | us-west-2              |

Web app will be listening on the standard Express port of 3000, but this can be changed by setting the `PORT` environmental variable.

# Containers

Public container image is [available on GitHub Container Registry](https://github.com/users/benc-uk/packages/container/package/nodejs-demoapp).

Run in a container with:

```bash
docker run --rm -it -p 3000:3000 ghcr.io/benc-uk/nodejs-demoapp:latest
```

Should you want to build your own container, use `make image` and the above variables to customise the name & tag.

## Kubernetes

The app can easily be deployed to Kubernetes using Helm, see [deploy/kubernetes/readme.md](deploy/kubernetes/readme.md) for details

# GitHub Actions CI/CD

A set of GitHub Actions workflows are included for CI / CD. Automated builds for PRs are run in GitHub hosted runners validating the code (linting and tests) and building dev images. When code is merged into master, then automated deployment to AKS is done using Helm.

[![](https://img.shields.io/github/workflow/status/benc-uk/nodejs-demoapp/CI%20Build%20App)](https://github.com/benc-uk/nodejs-demoapp/actions?query=workflow%3A%22CI+Build+App%22) [![](https://img.shields.io/github/workflow/status/benc-uk/nodejs-demoapp/CD%20Release%20-%20AKS?label=release-kubernetes)](https://github.com/benc-uk/nodejs-demoapp/actions?query=workflow%3A%22CD+Release+-+AKS%22)

# Optional Features

The app will start up and run with zero configuration, however the only features that will be available will be the INFO and TOOLS views. The following optional features can be enabled:

### AWS X-Ray

🚧 Coming soon.

The app has been instrumented with the AWS X-Ray SDK. All requests will be tracked, as well as dependant calls to MongoDB or other APIs (if configured), exceptions & error will also be logged.

[This article](https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-nodejs.html) has more information on monitoring Node.js with AWS X-Ray.

### Weather Details

Enable this by setting `WEATHER_API_KEY`

This will require a API key from OpenWeather, you can [sign up for free and get one here](https://openweathermap.org/price). The page uses a browser API for geolocation to fetch the user's location.  
However, the `geolocation.getCurrentPosition()` browser API will only work when the site is served via HTTPS or from localhost. As a fallback, weather for London, UK will be show if the current position can not be obtained

### User Authentication with Amazon Cognito

🚧 Coming soon.

Enable this by setting `COGNITO_IDENTITY_POOL_ID`.

### Todo App

Enable this by setting `TODO_MONGO_CONNSTR`

A mini todo & task tracking app can be enabled if a MongoDB backend is provided and a connection string to access it. This feature is primarily to show database dependency detection and tracking in App Insights

The default database name is `todoDb` but you can change this by setting `TODO_MONGO_DB`

You can stand up MongoDB in a container instance or in Cosmos DB (using the Mongo API). Note. When using Cosmos DB and the _per database provisioned RU/s_ option, you must manually create the collection called `todos` in the relevant database and set the shard key to `_id`

# Configuration

The following configuration environment variables are supported, however none are mandatory. These can be set directly or when running locally will be picked up from an `.env` file if it is present. A sample `.env` file called `.env.sample` is provided for you to copy

If running in Amazon ECS, all of these values can be injected as container environment variables into the Task Definition.

| Environment Variable                  | Default | Description                                                                      |
| ------------------------------------- | ------- | -------------------------------------------------------------------------------- |
| PORT                                  | 3000    | Port the server will listen on                                                   |
| TODO_MONGO_CONNSTR                    | _none_  | Connect to specified MongoDB instance, when set the todo feature will be enabled |
| TODO_MONGO_DB                         | todoDb  | Name of the database in MongoDB to use (optional)                                |
| WEATHER_API_KEY                       | _none_  | OpenWeather API key. [Info here](https://openweathermap.org/api)                 |
| COGNITO_IDENTITY_POOL_ID              | _none_  | Cognito Identity Pool ID                                                          |

## Deployment

See [deployment folder](./deploy) for deploying into Kubernetes with Helm or into Azure with Bicep and Container Apps.

# Updates

- Jul 2022 - Forked from Ben Coleman's repo and adapted to AWS (Thanks, Ben!)
- Nov 2021 - Replace DarkSky API with OpenWeather
- Mar 2021 - Refresh packages and added make + bicep
- Nov 2020 - Switched to MSAL-Node library for authentication
- Oct 2020 - Added GitHub Actions pipelines and Bicep IaC
- Jan 2020 - Added monitor page and API
- Jun 2019 - Added Azure AD login and profile page, cleaned up Todo app MongoDB code
- Apr 2019 - Updated to latest App Insights SDK package, and moved to Bootstrap 4
- Dec 2018 - Modified weather to use client browser location, rather than use IP
- Jul 2018 - Switched todo app over to MongoDB, fixed weather
- Feb 2018 - Updated App Insights monitoring
- Nov 2017 - Update to use Node 8.9
- Oct 2017 - Updated App Insights, improved Dockerfile
- Sept 2017 - Added weather page
- Sept 2017 - Major revamp. Switched to EJS, added Bootstrap and App Insights
- Aug 2017 - Minor changes and fixes for CRLF stuff
- July 2017 - Updated Dockerfile to use super tiny Alpine Node 6 image
- June 2017 - Moved repo to Github
