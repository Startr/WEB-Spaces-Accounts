from flask import Flask, flash, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin, LoginManager, login_user, logout_user, login_required, current_user

from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash

from functools import wraps

import csv
import os
import re
import logging
import stripe

config = {
    "DEBUG": True,  # run app in debug mode
    "SQLALCHEMY_DATABASE_URI": "sqlite:////tmp/test.db"  # connect to database
}


stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

app = Flask(__name__, static_url_path='')

app.secret_key = os.getenv("FLASK_SECRET_KEY")

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

def check_message(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        message = request.args.get('message')
        return f(*args, **kwargs)
    return decorated_function


def swuped(content, link="/dashboard", message="Go to the dash"):
    """
    Wrap html in swup div to allow for simple page transitions of content.

    content -- html to display
    link -- link to another page
    message -- anchor text for link
    note -- optional note to display coming from query string
    """
    note = request.args.get('message')

    return render_template('swuped.html', content=content, link=link, message=message, note=note)


@app.route('/')
@check_message
def index():
    return render_template('index.html', message=request.args.get('message'))


@app.route('/about')
def about():
    return swuped('This is the about page.', link="/contact", message="Go to the contact page.")


@app.route('/contact')
def contact():
    return swuped('This is the contact page.')


@app.route('/login', methods=['GET', 'POST'])
@check_message
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
@check_message
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
@check_message
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

@app.route('/free', methods=['GET', 'POST'])
@check_message
@login_required
def free():
    '''
    This function allows the user to create a free space.
    
    The user will be able to create a space_name and space_pass.

    TODO: Add automatic site archiving after 7 days
    TODO: Add automatic site reminders after every 7 days, include the # of visitors

    '''
    if request.method == 'POST':
        space_name = request.form.get('space_name')
        space_pass = request.form.get('space_pass')

        if not space_name or not space_pass:  # Check if both fields are filled in
            return redirect(url_for('index', message="Please provide both your Space's Name and Space's Password."))

        with open('contacts.csv', 'a', newline='') as file:
            writer = csv.writer(file)
            writer.writerow([current_user.email, space_name, space_pass,"Today's date"])
            # Run the site setup and make sure it's successful
            # If it is, redirect to the new space
            # In 7 days send an email to the user to remind them to upgrade
            # Also in 7 days dissable the space and collect visitor #s 
            # Email every week with # of visitors

            # If we don't have a local copy of the site, download it from https://github.com/Startr/WEB-Spaces/archive/refs/tags/0.0.1.zip
            if not os.path.exists('site'):
                os.system('wget https://github.com/Startr/WEB-Spaces/archive/refs/tags/0.0.1.zip')
                os.system('unzip 0.0.1.zip')
                os.system('mv WEB-Spaces-0.0.1 site')
                os.system('rm 0.0.1.zip')

            # Create a new folder for the space and name it the space_name, esure that the parent folder exists
            if not os.path.exists('sites'):
                os.makedirs('static/sites')

            # Check the csv if the user already has a space of the same name
            with open('contacts.csv', 'r') as file:
                reader = csv.reader(file)
                for row in reader:
                    if row[0] == current_user.email and row[1] == space_name:
                        # If they do, update the password
                        # The following is dummy code, it will need to be replaced with the actual code to update the password
                        os.system('echo ' + space_pass + ' > static/sites/' + space_name + '/password.txt')
                        logging.info('Updated password for ' + space_name)
                        return swuped('Your Space has been updated.', link="/free?reset.", message="Manage your space.")
                    
                    # If they don't, check if there's an existing folder with the same name
                    elif os.path.exists('static/sites/' + space_name):
                        return redirect(url_for('free?existis', message="A Space with that name already exists. Please choose another name."))
                    
                    # If they don't, create a new folder with the space_name
                    else:
                        os.makedirs('static/sites/' + space_name)
                        # copy the site/dist contents to the new folder
                        os.system('cp -r site/dist/* static/sites/' + space_name)
                        # create a password.txt file with the space_pass use the echo command
                        os.system('echo ' + space_pass + ' > static/sites/' + space_name + '/password.txt')
                        # TODO switch this for our staticrypyt site encryptor so we can encrypt the entire site
                        return swuped('Your Space is being created.', link="/free?reset.", message="Manage your space.")
    
    # Check if the user has a space_name in the csv file
    with open('contacts.csv', 'r') as file:
        reader = csv.reader(file)
        for row in reader:
            if row[0] == current_user.email:
                space_name = row[1]
                # exit the for loop
                break

    return render_template('free.html', space_name=space_name, message=request.args.get('message'))


@app.route('/pro_page')
@check_message
@login_required
def pro_page():
    if current_user.account_type == 'pro':
        return swuped('This is the pro page ' + str(current_user.name) + '.', link="/dashboard", message="Go to the dash")

    else:
        return redirect(url_for('upgrade'))


if __name__ == '__main__':
    app.jinja_env.auto_reload = True
    app.config['TEMPLATES_AUTO_RELOAD'] = True
    app.run(host='0.0.0.0', port=8000)
