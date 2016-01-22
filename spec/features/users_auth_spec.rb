require 'rails_helper'

feature 'Users' do

  context 'Regular authentication' do
    scenario 'Sign up' do
      visit '/'
      click_link 'Register'

      fill_in 'user_username',              with: 'Manuela Carmena'
      fill_in 'user_email',                 with: 'manuela@madrid.es'
      fill_in 'user_password',              with: 'judgementday'
      fill_in 'user_password_confirmation', with: 'judgementday'
      fill_in 'user_captcha',               with: correct_captcha_text
      check 'user_terms_of_service'

      click_button 'Register'

      expect(page).to have_content "You have been sent a message containing a verification link. Please click on this link to activate your account."

      confirm_email

      expect(page).to have_content "Your account has been confirmed."
    end

    scenario 'Errors on sign up' do
      visit '/'
      click_link 'Register'
      click_button 'Register'

      expect(page).to have_content error_message
    end

    scenario 'Sign in' do
      create(:user, email: 'manuela@madrid.es', password: 'judgementday')

      visit '/'
      click_link 'Sign in'
      fill_in 'user_email',    with: 'manuela@madrid.es'
      fill_in 'user_password', with: 'judgementday'
      click_button 'Enter'

      expect(page).to have_content 'You have been signed in successfully.'
    end
  end

  xcontext 'OAuth authentication' do
    context 'Twitter' do

      let(:twitter_hash){ {'provider' => 'twitter', 'uid' => '12345', 'info' => { 'name' => 'manuela' }} }
      let(:twitter_hash_with_email) { { 'provider' => 'twitter',
                                        'uid' => '12345',
                                        'info' => { 'name' => 'manuela' , 'email' => 'manuelacarmena@example.com', 'verified' => '1' } }
      }


      scenario 'Sign up, when email was provided by OAuth provider' do
        OmniAuth.config.add_mock(:twitter, twitter_hash_with_email)

        visit '/'
        click_link 'Register'

        expect do
          expect do
            expect do
              click_link 'Sign up with Twitter'
            end.not_to change { ActionMailer::Base.deliveries.size }
          end.to change { Identity.count }.by(1)
        end.to change { User.count }.by(1)

        expect(current_path).to eq(root_path)
        expect_to_be_signed_in

        click_link 'My account'
        expect(page).to have_field('account_username', with: 'manuela')

        visit edit_user_registration_path
        expect(page).to have_field('user_email', with: 'manuelacarmena@example.com')
      end

      scenario 'Sign up, when no email was provided by OAuth provider' do
        OmniAuth.config.add_mock(:twitter, twitter_hash)

        visit '/'
        click_link 'Register'

        expect do
          expect do
            expect do
              click_link 'Sign up with Twitter'
            end.not_to change { ActionMailer::Base.deliveries.size }
          end.to change { Identity.count }.by(1)
        end.to change { User.count }.by(1)

        expect(current_path).to eq(finish_signup_path)

        user = User.last
        expect(user.username).to eq('manuela-de-las-carmenas')
        expect(user.email).to eq("omniauth@participacion-12345-twitter.com")

        fill_in 'user_email', with: 'manueladelascarmenas@example.com'
        click_button 'Register'

        expect(page).to have_content "To continue, please click on the confirmation link that we have sent you via email"

        confirm_email

        expect(page).to have_content "Your email address has been successfully confirmed"

        visit '/'
        click_link 'Sign in'
        click_link 'Sign in with Twitter'
        expect_to_be_signed_in

        click_link 'My account'
        expect(page).to have_field('account_username', with: 'manuela')

        expect(user.reload.email).to eq('manueladelascarmenas@example.com')
      end

      scenario 'Sign in, user was already signed up with OAuth' do
        user = create(:user, email: 'manuela@madrid.es', password: 'judgementday')
        create(:identity, uid: '12345', provider: 'twitter', user: user)
        OmniAuth.config.add_mock(:twitter, twitter_hash)

        visit '/'
        click_link 'Sign in'

        expect do
          expect do
            click_link 'Sign in with Twitter'
          end.not_to change { Identity.count }
        end.not_to change { User.count }

        expect_to_be_signed_in
      end

      scenario 'Try to register with the username of an already existing user' do
        create(:user, username: 'manuela', email: 'manuela@madrid.es', password: 'judgementday')
        OmniAuth.config.add_mock(:twitter, twitter_hash_with_email)

        visit '/'
        click_link 'Register'
        click_link 'Sign up with Twitter'

        expect(current_path).to eq(finish_signup_path)

        fill_in 'user_username', with: 'manuela2'
        click_button 'Register'

        expect_to_be_signed_in

        click_link 'My account'
        expect(page).to have_field('account_username', with: 'manuela2')

        visit edit_user_registration_path
        expect(page).to have_field('user_email', with: 'manuelacarmena@example.com')
      end

      scenario 'Try to register with the email of an already existing user' do
        create(:user, username: 'peter', email: 'manuela@example.com')
        OmniAuth.config.add_mock(:twitter, twitter_hash)

        visit '/'
        click_link 'Register'
        click_link 'Sign up with Twitter'

        expect(current_path).to eq(finish_signup_path)

        fill_in 'user_email', with: 'manuela@example.com'
        click_button 'Register'

        expect(current_path).to eq(do_finish_signup_path)

        fill_in 'user_email', with: 'somethingelse@example.com'
        click_button 'Register'

        expect(page).to have_content "To continue, please click on the confirmation link that we have sent you via email"

        confirm_email
        expect(page).to have_content "Your account has been confirmed"

        visit '/'
        click_link 'Sign in'
        click_link 'Sign in with Twitter'
        expect_to_be_signed_in

        click_link 'My account'
        expect(page).to have_field('account_username', with: 'manuela')

        visit edit_user_registration_path
        expect(page).to have_field('user_email', with: 'somethingelse@example.com')
      end
    end
  end

  scenario 'Sign out' do
    user = create(:user)
    login_as(user)

    visit "/"
    click_link 'Sign out'

    expect(page).to have_content 'You have been signed out successfully.'
  end

  scenario 'Reset password' do
    create(:user, email: 'manuela@madrid.es')

    visit '/'
    click_link 'Sign in'
    click_link 'Forgotten your password?'

    fill_in 'user_email', with: 'manuela@madrid.es'
    click_button 'Send instructions'

    expect(page).to have_content "In a few minutes, you will receive an email containing instructions on resetting your password."

    sent_token = /.*reset_password_token=(.*)".*/.match(ActionMailer::Base.deliveries.last.body.to_s)[1]
    visit edit_user_password_path(reset_password_token: sent_token)

    fill_in 'user_password', with: 'new password'
    fill_in 'user_password_confirmation', with: 'new password'
    click_button 'Change my password'

    expect(page).to have_content "Your password has been changed successfully."
  end
end
