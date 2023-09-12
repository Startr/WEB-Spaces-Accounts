from flask import Flask, flash, render_template, request, redirect, url_for
from flask import send_from_directory, abort
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin, LoginManager, login_user, logout_user, login_required, current_user

from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash

from functools import wraps

import csv
import os
import sys
import re
import logging
import requests  # for downloading the site

import stripe

config = {
    "DEBUG": True,  # run app in debug mode
    "SQLALCHEMY_DATABASE_URI": "sqlite:////tmp/test.db"  # connect to database
}

site_db = 'sites.csv'

app = Flask(__name__, static_url_path='')

app.secret_key = os.getenv("FLASK_SECRET_KEY")

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

app.config.from_mapping(config)

db = SQLAlchemy(app)

if not os.path.exists('uploads'):
    os.makedirs('uploads')

login_manager = LoginManager()
login_manager.init_app(app)


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(100), unique=True)
    password = db.Column(db.String(100))
    name = db.Column(db.String(1000))
    account_type = db.Column(db.String(100))


with app.app_context():
    db.create_all()


@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


def swuped(content, link="/dashboard", message="Go to the dash", note=None):
    """
    Wrap html in swup div to allow for simple page transitions of content.

    content -- html to display
    link -- link to another page
    message -- anchor text for link
    note -- optional note to display coming from query string
    """
    return render_template('swuped.html', content=content, link=link, message=message, note=note)


@app.route('/')
def index():
    return render_template('index.html', message=request.args.get('message'))


@app.route('/about')
def about():
    return swuped('This is the about page.', link="/contact", message="Go to the contact page.")


@app.route('/contact')
def contact():
    return swuped('This is the contact page.')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')

        user = User.query.filter_by(email=email).first()

        if not user or not check_password_hash(user.password, password):
            return redirect(url_for('login', message="Incorrect email or password."))

        login_user(user)

        return redirect(url_for('free', message="You have been logged in."))
    # Get message from query string
    message = request.args.get('message')
    return render_template('login.html', message=message)


@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login', message="You have been logged out."))


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        email = request.form.get('email')
        name = request.form.get('name')
        password = generate_password_hash(
            request.form.get('password'), method='sha256')
        new_user = User(email=email, name=name,
                        password=password, account_type='free')
        # Handle existing user collision
        if User.query.filter_by(email=email).first():
            return redirect(url_for('register', message="Email address already exists."))
        db.session.add(new_user)
        db.session.commit()
        login_user(new_user)
        return redirect(url_for('free', message="You're now registered and logged in!"))

    message = request.args.get('message')
    return render_template('register.html', message=message)


@login_manager.unauthorized_handler
def unauthorized_callback():
    return redirect(url_for('login', message='You must be logged in to view that page.'))


@app.route('/dashboard')
@login_required
def dashboard():
    routes = []
    for rule in app.url_map.iter_rules():
        routes.append(str(rule))
    return render_template('dashboard.html', routes=routes)


@app.route('/upgrade', methods=['GET', 'POST'])
@login_required
def upgrade():
    # If user is already a pro user, redirect to pro page
    if current_user.account_type == 'pro':
        return redirect(url_for('pro_page', message="You are already a pro user."))
    if request.args.get('payment_intent'):
        payment_intent_id = request.args.get('payment_intent')
        payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)

        if payment_intent.status == 'succeeded':
            current_user.account_type = 'pro'
            db.session.commit()
            return swuped('You are now a pro user.', link="/pro_page", message="Go to the pro page.")

    else:
        # Ask stripe for customer id based on email
        stripe_customer_list = stripe.Customer.list(email=current_user.email)
        # If customer exists, get the id
        if stripe_customer_list['data']:
            stripe_customer_id = stripe_customer_list['data'][0]['id']
        else:
            new_customer = stripe.Customer.create(email=current_user.email)
            stripe_customer_id = new_customer['id']

        # create a new PaymentIntent for the upgrade fee
        payment_intent = stripe.PaymentIntent.create(
            amount=int(float(os.getenv("PRO_PRICE")) * 100),  # price from .env
            customer=stripe_customer_id,
            receipt_email=current_user.email,
            currency='usd',
            automatic_payment_methods={
                'enabled': True,
            }
        )
    return render_template('upgrade.html', client_secret=payment_intent.client_secret, stripe_publishable_key=os.getenv("STRIPE_PUBLISHABLE_KEY"))

# TODO: Add a way to cancel the subscription


# Function to download and extract site files if we don't already have them
# TODO check the version of the site and only download if it's not the latest
# https://gist.github.com/opencoca/afc180377b5b4aaf475da852042987ab
def download_and_extract_site():
    latest_site_version = '0.0.3.1'
    if not os.path.exists('site'):
        site_url = f'https://github.com/Startr/WEB-Spaces/archive/refs/tags/{latest_site_version}.zip'
        response = requests.get(site_url)
        if response.status_code == 200:
            with open(f'{latest_site_version}.zip', 'wb') as zip_file:
                zip_file.write(response.content)
            os.system(f'unzip {latest_site_version}.zip')
            os.system(f'mv WEB-Spaces-{latest_site_version} site')
            os.system('cd site && yarn install')
            os.remove(f'{latest_site_version}.zip')


def build_site():
    # TODO build the site
    os.system('cd site && yarn build')


def setup_space(space_name):
    """Setup a new space"""
    space_folder_path = f'sites/{space_name}'
    space_backup_path = f'site_backup/{space_name}'

    if os.path.exists(space_folder_path):
        logging.warning(f'Space {space_name} already exists')
        return redirect(url_for('free', message="A Space with that name already exists. Please choose another name."))
    else:
        build_site()
        os.makedirs(space_folder_path)
        logging.info(f'Created folder for {space_name} in static/sites')
        os.system(f'cp -r site/dist/* {space_folder_path}')
        logging.info(f'Copied site/dist contents to {space_folder_path}')
        # Backup the site/dist/index.html file to site_backup
        os.system(
            f'mkdir -p {space_backup_path} && \
              cp -f site/dist/index.html {space_backup_path}')
        logging.info(f'Copied site/dist/index.html to {space_backup_path}')


def delete_space(space_name):
    """Delete a space"""
    space_folder_path = f'sites/{space_name}'
    if os.path.exists(space_folder_path):
        os.system(f'rm -rf {space_folder_path}')
        logging.info(f'Deleted folder for {space_name} in static/sites')
    else:
        logging.warning(f'Space {space_name} does not exist')
        return redirect(url_for('free?nospace', message="A Space with that name does not exist."))


def update_space_password(space_name, space_pass):
    """
    Update the password for a space
    space_name -- the name of the space
    space_pass -- the new password for the space
    """
    command = (
        f'npm exec -- staticrypt site_backup/{space_name}/index.html -d sites/{space_name} '
        f'-p "{space_pass}" --short -t site/password_template.html'
    )
    os.system(command)
    logging.info(f'Updated password for {space_name} using staticrypt')


def unix_timestamp():
    import time
    return str(int(time.time()))


@app.route('/free', methods=['GET', 'POST'])
@login_required
def free():
    '''
    TODO: Add automatic site archiving after 7 days
    TODO: Add automatic site reminders after every 7 days, include the # of visitors

    '''
    if request.method == 'POST':
        space_name = request.form.get('space_name')
        space_pass = request.form.get('space_pass')

        if not space_name or not space_pass:  # Check if both fields are filled in
            return redirect(url_for('free', message="Please provide both your Space's Name and Space's Password."))

        data = []
        with open(site_db, 'r') as file:
            reader = csv.reader(file)
            for row in reader:
                data.append(row)

        for idx, row in enumerate(data):
            if row[0] == current_user.email and row[1] == space_name:
                # Write new password to csv file in the same row
                data[idx][2] = space_pass
                # Write the new csv file
                with open(site_db, 'w') as file:
                    # append the new row
                    writer = csv.writer(file)
                    writer.writerows(data)

                # update the password using staticrypt
                update_space_password(space_name, space_pass)

                return swuped('Your Space has been updated.', link="/free?reset.", message="Manage your space.")

            elif row[0] != current_user.email and row[1] == space_name:
                return redirect(url_for('free', message="A Space with that name already exists. Please choose another name."))

            elif row[0] == current_user.email and row[1] != space_name:
                # delete the old space and update the csv file to not include it
                delete_space(row[1])
                data.pop(idx)
                with open(site_db, 'w') as file:
                    writer = csv.writer(file)
                    writer.writerows(data)

        with open(site_db, 'a', newline='') as file:
            writer = csv.writer(file)
            writer.writerow([current_user.email, space_name,
                            space_pass, "Today's date"])

        # TODO In 7 days send an email to the user to remind them to upgrade
        # TODO Also in 7 days dissable the space and collect visitor #s
        # TODO Email every week with # of visitors

        download_and_extract_site()
        setup_space(space_name)
        update_space_password(space_name, space_pass)

        now = unix_timestamp()

        return swuped('Setting up your space...', link="/free?now=" + now, message="Manage your space.")

    elif request.method == 'GET':
        # Check if the user has a space_name in the csv file
        # If they do return the space_name and space_pass
        with open(site_db, 'r') as file:
            reader = csv.reader(file)
            for row in reader:
                if row[0] == current_user.email:
                    space_name = row[1]
                    space_pass = row[2]
                    return render_template('free.html',
                                           space_name=space_name,
                                           space_pass=space_pass,
                                           message=request.args.get('message'))

        # If they don't, return the default page
        return render_template('free.html', message=request.args.get('message'))

    else:
        return redirect(url_for('free', message="Something went wrong."))


def site_builder():
    ''' 
    Checks the sites.csv file for new spaces and builds them.
    Checks the sites/ folder for sites that are not in sites.csv and deletes them.
    '''
    # Download the site files if we don't already have them
    download_and_extract_site()
    # empty the sites/ folder
    os.system('rm -rf sites/*')
    # Check the csv file for new spaces
    with open(site_db, 'r') as file:
        reader = csv.reader(file)
        for row in reader:
            if not os.path.exists('sites/' + row[1]):
                # If the space doesn't exist, set space_name and space_pass
                # and build the space
                space_name = row[1]
                space_pass = row[2]
                setup_space(space_name)
                update_space_password(space_name, space_pass)


@app.route('/pro_page')
@login_required
def pro_page():
    if current_user.account_type == 'pro':
        return swuped('This is the pro page ' + str(current_user.name) + '.', link="/dashboard", message="Go to the dash")

    else:
        return redirect(url_for('upgrade'))


@app.route('/sites/<path:path>')
def send_site(path):
    if os.path.isdir('sites/' + path):
        path += '/index.html'
    return send_from_directory('sites/', path)


if __name__ == '__main__':
    if '--clean' in sys.argv:
        os.system('rm -rf site')
        os.system('rm -rf sites')
    # run the site_builder on launch to make sure we have a clean sites/ folder
    site_builder()
    app.jinja_env.auto_reload = True
    app.config['TEMPLATES_AUTO_RELOAD'] = True
    app.run(host='0.0.0.0', port=8000)
