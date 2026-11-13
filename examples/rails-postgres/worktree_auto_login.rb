# frozen_string_literal: true

# Copied in by the setup hook and kept out of git by .git/info/exclude. Written for an app whose
# Devise model is UserIdentity; change the model and the signed-in helper to match yours.
# Signs a worktree's browser straight in as WT_AUTO_LOGIN_EMAIL, set in .env_overrides.rb.
# Sign-in pages are skipped, so signing out and in as someone else still works.
return unless Rails.env.development? && ENV['WT_AUTO_LOGIN_EMAIL'].present?

Rails.application.config.to_prepare do
  ApplicationController.prepend_before_action(unless: :devise_controller?) do
    next if user_identity_signed_in?

    identity = UserIdentity.find_by(email: ENV['WT_AUTO_LOGIN_EMAIL'])
    sign_in(identity) if identity
  end
end
