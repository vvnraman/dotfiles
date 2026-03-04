# Allow 10 password retries
echo "Defaults passwd_tries=10" | sudo tee /etc/sudoers.d/01_password_retries
sudo chmod 440 /etc/sudoers.d/01_password_retries

# Do this for hyprlock as well
sudo sed -i 's/^# *deny = .*/deny = 10/' /etc/security/faillock.conf
