![alt text](https://source.unsplash.com/random/901x200/?screens*bw "Startr Web App")

# Startr Spaces Web Accounts  -  Built with Startr/WEB-Flask

v0.0.1

# Startr Spaces Web Accounts

Built with Startr/WEB-Flask

## Introduction

Welcome to Startr Spaces Web Accounts. This is a simple yet powerful members only application built with Startr/WEB-Flask. It is a great starting point for building communities with Python and Flask.

### Getting Started

To begin, make sure you have Python installed on your machine. Clone this repository and navigate to the project directory in your terminal. Then, follow these steps:

Note: To keep things simple we are using the built in Flask server. For production you will want to use a WSGI server like Gunicorn or uWSGI.

0. Make sure pipevn is installed `pip install pipenv` or on mac `brew install pipenv`
1. Setup your environment variables in `.env` file. You can use the `.env.example` file as a template.
2. Setup your pipevn environment `pipenv install`
3. Activate your pipevn environment `pipenv shell` or if you have autoenv installed `cd ../
4. Run the app locally using `pipenv run python app.py`. The application will be accessible at `http://localhost:8000` during development.

## License

We license our projects under the [AGPL-3.0](https://choosealicense.com/licenses/agpl-3.0/) license. This license allows you to use, modify, and distribute this work, as long as you give us credit and share any changes you make under the same license. Share your changes by opening a pull request.

##  Includes 🛠️

## Includes 🛠️

Here's what you'll find in this awesome project:

> **Note:** To access the links, you must be running the development server on your local machine at `127.0.0.1:8000`.

- ✨ [Quick Site](http://127.0.0.1:8000/) with super smooth page transitions
- 🔐 [User Authentication](http://127.0.0.1:8000/login/)
- 👥 [Members Only Page Logic](http://127.0.0.1:8000/members/)
- 🎯 [Pro Members Only Page Logic](http://127.0.0.1:8000/pro-members/)
- 📝 [Contact Form](http://127.0.0.1:8000/contact/)
- 📂 [File Upload](http://127.0.0.1:8000/upload/)
- 💵 Billing
  - 💳 [Stripe Integration](http://127.0.0.1:8000/billing/stripe/)
  - 🔄 [Subscriptions](http://127.0.0.1:8000/billing/subscriptions/)
- 📊 [User Dashboard](http://127.0.0.1:8000/dashboard/)
- 👩‍💼 [User Roles](http://127.0.0.1:8000/user-roles/)
- 🔑 [Login](http://127.0.0.1:8000/login/)
- 🔒 [Logout](http://127.0.0.1:8000/logout/)
- 📝 [User Registration](http://127.0.0.1:8000/register/)

Each link provides a direct path to the corresponding feature, ensuring you can explore and interact with the components seamlessly.

## Directory Structure & Data Organization 📁

This application is organized with a clean, Docker-friendly directory structure that keeps all persistent data in a single `data/` volume:

### Data Directory Structure

```
data/
├── app.db                    # SQLite database (user accounts, sessions)
├── site/                     # Site template source (downloaded & built from GitHub)
│   ├── dist/                 # Built site files ready for deployment
│   ├── src/                  # Source files for the site template
│   ├── package.json          # Node.js dependencies for site building
│   ├── password_template.html # Template for password-protected sites
│   └── ...                   # Other site template files
└── sites/                    # Generated user spaces (served to visitors)
    ├── {space_name_1}/       # Individual user space files
    │   ├── index.html        # Password-protected entry point
    │   ├── assets/           # Static assets (CSS, JS, images)
    │   └── ...
    ├── {space_name_2}/       # Another user space
    └── ...
```

### Other Important Directories

```
uploads/                      # User uploaded files
site_backup/                  # Backup copies of original site templates
├── {space_name}/
│   └── index.html           # Original unprotected site template
templates/                    # Flask HTML templates
static/                       # Flask static assets (CSS, JS, images)
markdown/                     # Markdown content files
```

### Benefits of This Structure

- **🐳 Docker-Friendly**: All persistent data is contained in the `data/` directory, making it easy to mount as a single Docker volume
- **📦 Clean Separation**: Source templates (`data/site/`) are separate from user-generated content (`data/sites/`)
- **💾 Easy Backup**: Single directory contains all important application data
- **🔄 Version Control**: Only application code is tracked in git, not generated content
- **🚀 Scalable**: Clear organization supports multiple user spaces and easy deployment

### Site Generation Flow

1. **Template Download**: Latest site template is downloaded to `data/site/` from GitHub
2. **Site Building**: Template is built using Node.js/Yarn, output goes to `data/site/dist/`
3. **Space Creation**: Built files are copied to `data/sites/{space_name}/` for each user
4. **Password Protection**: Sites are protected using StaticCrypt and served from `data/sites/`
5. **Web Serving**: Flask serves user sites from `data/sites/` via `/sites/{space_name}/` URLs


## More details

To ensure you have a seamless experience using WEB-Flask, we've prepared a more detailed description below:

1. **Installation:** First, follow the "Getting Started" section above to set up the environment and run the app locally.
2. **Page Transitions:** Explore the super smooth page transitions and enjoy a seamless user experience.
3. **Stripe Integration:** Learn how to integrate Stripe for payment processing with just a few simple steps.
4. **User Authentication:** Implement user authentication to secure your app's content.
5. **Members Only Logic:** Control access to certain pages and make them exclusive to members only.
6. **Pro Members Logic:** Elevate the experience for pro members with special access and content.
7. **Contact Form:** Set up a contact form to connect with your users and receive valuable feedback.
8. **File Upload:** Allow users to upload files effortlessly with this feature.
9. **Billing and Subscriptions:** Manage billing and subscriptions smoothly for your users.
10. **User Dashboard:** Create a personalized dashboard for users to monitor their activities and settings.
11. **User Roles:** Define different user roles for varying levels of access and control.
12. **Login and Logout:** Enable users to log in and out securely.
13. **User Registration:** Implement user registration to create accounts for your app.

## Get Started Now!

You are all set to embark on an exciting journey with WEB-Flask. Get ready to build amazing web applications with just 256 lines of Python magic. Happy coding! 🎉🐍

## Installation

**Note:** It's a great idea to use a tool like autoenv to manage spinning up your app's env while doing development.

```bash
curl -#fLo- 'https://raw.githubusercontent.com/hyperupcall/autoenv/master/scripts/install.sh' | sh
````

```bash
pip install -r requirements.txt

echo export STRIPE_SECRET_KEY="{{ your_stripe_secret_key }}" >> .env
echo export STRIPE_PUBLISHABLE_KEY="{{ your_stripe_publishable_key }}" >> .env
echo export FLASK_SECRET_KEY="{{ your_flask_secret_key }}" >> .env

# Sets a default price for the Pro plan
# Currently, this is a one-time payment

echo export PRO_PRICE="{{ your_pro_price }}" >> .env

# Sets a default price for the Pro plan
# Currently, this is a one-time payment

echo export NODE_OPTIONS=--openssl-legacy-provider >> .env

echo echo "Keys set" >> .env

echo pipenv shell >> .env
```

## Usage

```bash
python app.py
```

Browse to http://localhost:8000 and enjoy!

While in development, the user database is stored in `/tmp/users.db`. This facilitates
easy testing and development. In production, you'll want to change this to a more
permanent location.

## Deployment

Use Docker to deploy this application. The included `Dockerfile` will build an image
with the application and all dependencies installed.

### Docker Volume Mounting

For persistent data storage, mount the `data/` directory as a volume:

```bash
docker run -v /host/path/to/data:/app/data -p 8000:8000 your-image-name
```

This ensures that:
- User databases persist across container restarts
- Generated user sites are preserved
- Site templates are cached and don't need to be re-downloaded

We also include a `captain-definition` file for use with [Caprover](https://caprover.com/). This
file will automatically deploy the application to your Caprover instance.

**Note:** You will need to set the environment variables in your Caprover instance and configure persistent volumes for the `data/` directory.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss
what you would like to change.

