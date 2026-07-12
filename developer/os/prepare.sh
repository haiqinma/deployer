# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install iterm2
brew install --cask iterm2

# install oh-my-zsh

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

## install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

## 修改 `~/.zshrc` 文件中的plugins，整行替换
sed -i '' 's/^plugins=.*/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/' ~/.zshrc

# install python3

## install pyenv
brew install uv
brew install pyenv
brew install xz

## 在文件中 `~/.zshrc` 添加环境变量，执行命令
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init - zsh)"' >> ~/.zshrc

## install python 3.12
pyenv install 3.12
pyenv global 3.12.13

# install nodejs

## install nvm
deployer/developer/node/install.sh

## install nodejs 24
nvm install 24

## install claude-code
npm install -g @anthropic-ai/claude-code

## install codex
npm install -g @openai/codex

