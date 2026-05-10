# Add Backend to React with Django REST Framework and Docker

In this tutorial, I’ll show you how to add a Django REST Framework Backend to a React project.

Django REST Framework is an addition to Django that adds functionality, making it easier to build backend REST APIs.

We’ll follow on from where we left off in the previous tutorial: How to Dockerize a React Project.

In that guide, we show you how to create a React project using Docker.

Although that tutorial is optional, you might find it useful to follow it first to get an understanding of Docker/React.

Also, if you want to become a Django REST Framework expert, check out our courses:

- Build a Backend REST API – Beginner
- Build a Backend REST API – Advanced

## Prerequisites
You’ll need the following:

- Docker and Docker Compose – I recommend using Docker Desktop or Colima
- The starting source code: LondonAppDeveloper/dockerize-react
- A code editor – I use VSCode
- Once you have those items, we can get started.

## Housekeeping
We’ll start by cloning the starting project code.

Open your Terminal or PowerShell and use cd to change to the directory where you keep your projects.

Then run the following:

```git clone https://github.com/LondonAppDeveloper/dockerize-react.git```

We need to make a few small changes to this project.

## Add .gitignore file
Create a new file called .gitignore in the root of the project and add the content from this file.

This includes both the Python.gitignore and Node.gitignore templates from GitHub.

We add this to prevent certain working files being added to the Git repo. Such as the auto generated Python runtime files that are stored in the __pycache__.

## Rename the Dockerfile
(See the full diff on GitHub)

Rename the Dockerfile to Dockerfile.frontend.

Open docker-compose.yml and add the dockerfile: Dockerfile.frontend line under the context: . line so it looks like this:

```
services:
  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
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

We change this because the existing Dockerfile is specifically for the frontend code. We’ll be adding a separate one for the backend.

Usually I use the root Dockerfile for the backend, since this is what underpins our application.

## Add Dockerfile for Backend
(See the full diff on GitHub)

Add a requirements.txt file with the following contents:

```
Django==5.1.3
```

This will be used to install Django into our Dockerfile, which we’ll create next…

In the root of the project, create a new file called Dockerfile with the following contents:

```
FROM python:3.13.0-alpine3.20

ENV PYTHONUNBUFFERED 1

COPY ./requirements.txt /requirements.txt
COPY ./backend /backend
WORKDIR /backend

RUN python -m venv env /py && \
    /py/bin/pip install --upgrade pip && \
    /py/bin/pip install -r /requirements.txt

ENV PATH="/py/bin:$PATH"

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

The Dockerfile defines the steps for building the image.

Let me explain this file line-by-line:

FROM python:3.13.0-alpine3.20 specifies the base image. This is the starting point for our Docker image. We pin the versions to Python 3.13.0 to ensure that the steps are consistent and we use the Alpine Linux version of the image because it’s very lightweight.

ENV PYTHONUNBUFFERED 1 is a standard line we add to Python-based Docker images because it ensures that output is “unbuffered”. The reason for this is explained in depth on Stack Overflow.

COPY ./requirements.txt /requirements.txt
COPY ./backend /backend

These lines will copy the requirements.txt file in our project to the Docker image.

WORKDIR /backend sets the default working directory to /backend – this means any command we run will run from the /backend directory.

RUN python -m venv env /py && \
/py/bin/pip install --upgrade pip && \
/py/bin/pip install -r /requirements.txt

This will run 3 shell commands. The first will create a new Python virtual environment in /py that we’ll use for our project. The next one will upgrade pip to the latest version. Finally, we’ll install the requirements.txt that we copied previously.

Here are a few things to keep in mind with this line:

We put all 3 commands in one single RUN statement separated by && – This is because each line in a Dockerfile will create a new layer of our image. It’s best to keep layers to the minimum required to optimise caching
We create the /py virtual environment to isolate our Python requirements inside our Docker image. Some people suggest this is not necessary because our Docker image is already isolated. I disagree, because it’s possible (although admittedly rare) that the Docker image has it’s own Python dependencies
Instead of using pip install, we use /py/bin/pip install to ensure that the dependencies are installed (or upgraded) inside our /py virtual environment specifically
ENV PATH="/py/bin:$PATH" will add our Python virtual environment to the system path. This allows us to run commands from packages installed inside our virtual environment without specifying /py/bin/python.

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"] specifies the default command for containers running from this image. In this case, we run our Python development server, binding it to the 0.0.0.0 (all network interfaces) host, so we can access it through a mapped port that we’ll add later.

## Test Building Docker Image
Create a new empty directory called backend in the root of the project so that the build doesn’t fail on the COPY ./backend /backend.

Then run:

```docker build .```

This will build your Docker image, and let you know if there are any typos.

## Add Backend Service to Docker Compose
(See full Diff on GitHub)

Add the following to the bottom of the docker-compose.yml file (make sure your indentation of the file is correct):

```
  backend:
    build:
      context: .
    ports:
      - 8000:8000
    volumes:
      - ./backend:/backend
```

This does the following:

Creates a new service called “backend”
Sets the build context to :. and specifies the root Dockerfile
Maps port 8000 on the container to port 8000 on the host
Sets up a volume mapping the backend directory in our project to /backend in our container
If you followed the How to Dockerize a React Project tutorial you might wonder why we don’t use the new watch functionality for the backend?

The reason is because volumes work well for Python projects, and they also provide two way syncing. I only use watch for node projects because it has difficulty detecting file changes in Docker volumes for reasons related to the underlying implementation of Node file monitoring.

Next, we’ll create a Django project by running the following:

docker compose run --rm backend sh -c "django-admin startproject backend ."
This will create a new Django project called backend. You should see all the files appear in the backend/ directory of our project after you run that command.

## Create a Backend API
(See full diff on GitHub)

Now we’ll create a very basic API in Django REST Framework.

We are going to keep it simple, just to demonstrate how to integrate it with React.

### Update requirements.txt
Add the following lines to requirements.txt

```
djangorestframework==3.15.2
django-cors-headers==4.6.0
```

This will install Django REST Framework which will help us build our API.

It also installed django-cors-headers which helps us manage CORS (Cross Origin Resource Sharing). It will allow us to make requests to our Django API from different domain/ports so we can configure Django to accept requests made from our app running on http://localhost:5173.

### Update settings.py
Open backend/backend/settings.py and make the following changes.

In the INSTALLED_APPS list, add the following two lines:

```
    'corsheaders',
    'rest_framework'
```

This will enable the corsheaders and rest_framework apps in our Django project.

Next, in the MIDDLEWARE list, insert the following above the django.middleware.common.CommonMiddleware line:

```
'corsheaders.middleware.CorsMiddleware',
```

This is required for the coresheaders app to work.

Then, add the following to the bottom of settings.py:

```
CORS_ALLOWED_ORIGINS = ["http://localhost:5173"]
```

This will allow our app that runs on http://localhost:5173 to make requests to our API running on http://localhost:8000. This is also applicable for production, because often you need to support running the Django app on a separate server to the frontend (depending how you configure your deployment).

### Create a Simple API
We are going to implement a very basic API which returns the words “Hello World” and the current date time in ISO format.

Create a new file at backend/backend/views.py and populate it with the following:

```
from datetime import datetime

from rest_framework.decorators import api_view
from rest_framework.response import Response


@api_view(['GET'])
def hello_world(request):
    """Hello world endpoint."""
    return Response({'message': f'Hello World: {datetime.now().isoformat()}'})
```

Using the functional view decorators, this creates a simple view that accepts an HTTP GET request and returns a Response. 

### Map URL to API
Finally we can map our view to a URL to make it accessible in our project.

Open backend/backend/urls.py and update it to look like this:

```
from django.contrib import admin
from django.urls import path

from backend.views import hello_world

urlpatterns = [
    path('api/hello-world/', hello_world),
    path('admin/', admin.site.urls),
]
```

### Test API
Start the development server by running the following:

```
docker compose up --build --watch
```

Then navigate to: http://127.0.0.1:8000/api/hello-world/

You should see something like this:


## Call API from React
(See full diff on GitHub)

Now we have an API created and running, we can update our React project to use it.

Open frontend/src/App.jsx and update the contents to look like this:

```
import { useState } from "react";
import reactLogo from "./assets/react.svg";
import viteLogo from "/vite.svg";
import "./App.css";

function App() {
  const [response, setResponse] = useState("");

  const updateResponse = async () => {
    const res = await fetch("http://localhost:8000/api/hello-world/");
    const data = await res.json();
    setResponse(data["message"]);
  };

  return (
    <>
      <div>
        <a href="https://vitejs.dev" target="_blank">
          <img src={viteLogo} className="logo" alt="Vite logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
      </div>
      <h1>Vite + React</h1>
      <div className="card">
        <button onClick={() => updateResponse()}>
          response is: {response}
        </button>
        <p>
          Edit <code>src/App.jsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite and React logos to learn more
      </p>
    </>
  );
}

export default App;
```

You can see the full diff here on GitHub.

The changes are as follows:

- We update the existing “count” state to “response”. We’ll use this to store the response the API sends, instead of the existing count which is provided by the React template
- We add an updateResponse function that will call our API using the fetch API. This function makes a request, retrieves the JSON response and sets the message value in the React state, using the setResponse function
- Finally we update the button to call this new function

Now let’s test it.

You should have the server already running from a previous step. If not, run the following:

```
docker compose up --build --watch
```

Then open http://127.0.0.1:5173 and test by clicking the button.

You should see the response updating with the value returned from the API.

If you open up your developer tools (I’m using Firefox here), you can see the request being submitted in the Network tab:


And that’s how you add a Django REST Framework backend to a React project using Docker.

Please give us your thoughts on what you’d like us to add next in the comments!











