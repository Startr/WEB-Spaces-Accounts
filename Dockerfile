# start by pulling the python image
FROM python:3.9-alpine

# Set environment variables for the desired Node.js and npm versions
ENV NODE_VERSION=18.12.1
ENV NPM_VERSION=9.6.0

# Install required dependencies
RUN apk update && apk upgrade && \
    apk add --no-cache curl make gcc g++ python3

# Download and install Node.js
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz | tar -xJ -C /usr/local --strip-components=1 

# Add the Node.js binary directory to the PATH
ENV PATH="/usr/local/bin:${PATH}"

# Check Node.js version
RUN node -v

# Install npm using the updated PATH
RUN curl -fsSL https://www.npmjs.com/install.sh | sh

# Cleanup unnecessary dependencies
RUN apk del curl make gcc g++ python3 && \
    rm -rf /var/cache/apk/*

# Check Node.js and npm versions
RUN node -v && npm -v

RUN npm install -g npx yarn


ENTRYPOINT ["bash", "-c"]

# copy the Pipfile and Pipfile.lock from the local file to the image
COPY ./Pipfile /app/Pipfile
COPY ./Pipfile.lock /app/Pipfile.lock

# install pipenv
RUN pip install pipenv

# switch working directory
WORKDIR /app

# install the dependencies and packages in the requirements file
RUN pipenv install 

# copy every content from the local file to the image
COPY . /app

EXPOSE 8000

# Run our CMD within the virtual environment
CMD ["pipenv run python app.py"]