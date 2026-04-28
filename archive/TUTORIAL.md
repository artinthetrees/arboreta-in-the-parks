
# How to Dockerize a React Project
In this tutorial I’ll explain how to set up a new React project using Docker and Vite so that auto reloading works.


## Prerequisites
You’ll need the following:

- Docker and Docker Compose – I recommend using Docker Desktop or Colima
- A code editor – I use VSCode

## Resources
The full and final version of this tutorial can be found here: https://github.com/LondonAppDeveloper/dockerize-react

## Creating React Project
First, we’ll create a new React project.

- Open your terminal and create a new directory you wish to use for your project.

**Note:** I will be creating the react project as a subdirectory in the root of the project directory. This is so we can use the root directory for the Docker configuration. Also, in many projects the root directory is used for the backend.

- Next, run the following command to create a new React project called “frontend”.

macOS / Linux:

```docker run --rm -it -v $(pwd):/code -w /code node:22.11 sh -c "npm create vite@5.4 frontend -- --template react && cd frontend/ && npm install"```

Windows:

```docker run --rm -it -v $(PWD):/code -w /code node:22.11 sh -c "npm create vite@5.4 frontend -- --template react && cd frontend/ && npm install"```

**ART NOTE:** replace $(PWD) with %cd%

- When asked to install the create-vite package, type y and hit enter to proceed:

**Let me explain this command section by section:**

docker run: the command for running containers in Docker

--rm: tells docker to remove the container after it’s finished running (this prevents containers lingering on the system once they are used).

-it: Tells Docker to run the command “interactively” – this is so we can provide inputs to the command we run in Docker in the terminal.

-v $(pwd):/code (macOS) or -v $(PWD):/code (Windows): Maps the current working directory from your local machine to the running container – this basically shares our current directory with the /code directory in our running containers filesystem.

-w /code – Tells Docker to set the working directory to /code (similar to running cd /code).

node:22.11 – The image we want to run, with the version tag (to keep these steps consistent).

sh -c – This forms the first part of the command we run. It allows us to provide a “shell” command that will run in the container inside quotations after this command. It’s optional, but I find it useful to separate the Docker syntax from the command we want to run in Docker.

npm create vite@5.4 frontend -- --template react: This is the command for creating a new vite project with a react template as per the vite documentation.

&& cd frontend/ – This moves us into the directory of the new project inside Docker (&& is used to chain multiple commands together)

&& npm install – This installs the dependencies defined in the package.json that is created by the npm create command. This is done so we get the package-lock.json file for these dependencies.

**Why the long command?**
I imagine you’re asking: why on earth do you use such a huge command for creating a simple project? Why not just run npm directly?

It’s a fair question, and feel free to npm create vite@5.4 frontend -- --template react if you already have npm setup and installed.

The reason I use Docker is because while most people understand the value of using it for deployment, few utilise it’s full potential for local development.

Running the command using Docker ensures that everyone following this tutorial is running exactly the same command, with the same versions of node and vite.

Hopefully this means that if you’re following these steps in 2 weeks or 2 years, it should still work for you the same way.

Also, it means it doesn’t matter which version of node, vite, or anything else you have installed directly on your machine, because we are running it through a controlled Docker environment.

This is not only applicable for tutorials, but also when you’re working in teams and companies.

How many times have you started a new job, only to open up the project to find the README.md is 5 years old and none of the “getting started” steps work anymore? (for those new to the field, you have that to look forward to!)

Let’s keep going…

## Configure Docker

Next we’ll create a Docker configuration.

All of these files will go in the root of the project (not inside frontend/).

If you prefer, you can see the code changes here on GitHub.

1) Add a new file called .dockerignore:

```
README.md
frontend/node_modules/
```

This tells Docker which files to ignore when it gathers up files from the context to build our image. It’s mostly beneficial from a performance standpoint, as it makes the build process faster because it doesn’t need to transfer unnecessary files to the Docker builder.

2) Then, add a new file called Dockerfile:

```
FROM node:22.11

COPY ./frontend /frontend
RUN rm -rf /frontend/node_modules

WORKDIR /frontend
RUN npm ci

CMD ["npm", "run", "dev"]
```

This provides Docker with the instructions on how to build our image.

Each line is a new step in the build process.

I’ll break it down line-by-line below:

FROM node:22.11 – Defines the base image (starting point) for our image. In this case we are building on top of the node image, version 22.11 (currently LTS version at the time of writing this tutorial).

COPY ./frontend /frontend – This copies all the files in the frontend directory in our project into the image we are building.

RUN rm -rf /frontend/node_modules – In-case we have the node_modules/ installed locally, we want to clean them out from our Docker image. This is because we will be installing them fresh inside the image in a future step.

WORKDIR /frontend – Tells docker that the default working directory of containers built from this image should be the /frontend directory in the container. This means all commands run from /frontend, as if you had run cd /frontend before the command.

RUN npm ci – Installs the NPM packages defined in package.json and package-lock.json. Why do we not use npm install? Great question. The ci command is similar to running npm install, except it doesn’t update the package-lock.json. This is because when the image is being built, it can’t sync files back to our project, so we don’t want a situation where the package-lock.json in our Docker image is different from the one in our project code, as we may run into unexpected issues that are hard to debug.

CMD ["npm", "run", "dev"] – Sets the default command that runs for this image (in this case, it will start the vite development server which is set in the package.json “dev” line under the scripts block).

3) Add a new file called docker-compose.yml in the root of the project:

```
services:
  frontend:
    build:
      context: .
    ports:
      - 5173:5173
    develop:
      watch:
        - action: sync
          path: ./frontend/
          target: /frontend
          ignore:
            - node_modules

```

Let me break that down…

We define a services block with frontend as our first (and only) service.

Then, we specify the build context as the root directory using the period character. This tells Docker Compose that we want to use the Dockerfile found in the root of the project for this service.

We map ports 5173 on our local machine to the same port in the Docker container. This ensures we can access the vite server running inside the Docker containers isolated network.

Next, we have the develop block.

This utilises the new watch feature of Docker Compose.

It’s designed to watch files in our local machine and sync them to the running container when they change.

Previously, we’ve had to use volumes for this. The problem with volumes is it’s not optimised for syncing file changes for node projects. Also, you can’t exclude files like node_modules which always is a pain when Dockerizing node.

The downside is that it only provides one way syncing (from the host to the container) and not reverse. We’ll talk more about that later.

I’ll explain each line of the watch block below:

action: sync tells Docker Compose to sync the files every time something changes in the watched path. Other options for this include restart (restart the container) and rebuild (rebuild the docker image). You can see more in the official docs. We only need to sync, because this is enough for vite to detect changes and reload the development server.

path: ./frontend/ tells Docker to watch files in the frontend/ directory of our project

target: /frontend – Tells docker to sync the files in our path to the /frontend directory inside our running container.

ignore: – Tells Docker to ignore the node_modules/ directory – this is important because this directory often contains billions of files (I’m exaggerating a bit but it’s not far off), which make syncing very inefficient. Also, the files in our node_modules/ might vary since we have a different OS to the Docker Container. It’s best to keep the node_modules/ inside the container separate from the one on our local machine.

## Configure vite

Next we need to make a minor change to our vite config.

You can see the full diff here on GitHub.

Open the frontend/vite.config.js file and modify the contents to look like this:

```
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: { host: "0.0.0.0" },
});
```

This updates the server to listen on host: 0.0.0.0.

We need to do this because vite will only bind to localhost, which means it’s only accessible from the local network inside the docker container network (which is not accessible from our local machine).

Setting the host to 0.0.0.0 tells the server to listen on all network interfaces of the docker container’s network. This ensures we can access it via the mapped port of 5173.

## Running the Server

Now we can finally run the server!

1) Open the Terminal/PowerShell and run the following:

```
docker compose up --watch --build
```

This will build our container and start the image.

2) Then, open http://127.0.0.1:5173 and you should see the sample vite placeholder app.

3) Test by making a change to any file in the React code, and you should see the server auto-reload.

## Adding Node Packages

As mentioned above, the downside of using the “watch” functionality in Docker Compose is that it only syncs files one way – from your system to the container.

This means, if you want to install NPM packages using pure docker (and not by running npm install PACKAGE directly on your machine) there is an additional step to follow.

1) If you want to add node packages, you will need to run the following command:

**macOS:**

```
docker compose run --rm -v $(pwd):/frontend frontend sh -c "npm install PACKAGE"
```

**Windows:**

```
docker compose run --rm -v "$(PWD):/frontend" frontend sh -c "npm install PACKAGE"
```

This runs a command through our configured frontend service, which will install the package and update package-lock.json. The -v $(pwd):/frontend ensures that a volume is mapped, which (unlike the watch config) ensures two way syncing is possible. This allows the package-lock.json in our project to be updated by the command running inside Docker.

2) After you run this, you’ll need to rebuild the container again.

- Simply use CMD + C (macOS) or CTRL + C to stop our running service.

- Then run the docker compose up --watch --build command again.

This ensures that the new dependency is installed in the running docker container.

## Summary
That’s how you create and configure a React app using Docker Compose.

Thanks for reading!

