
# how to copy vscode extensions on macos

# use code binary
echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> ~/.zshrc
source ~/.zshrc

# export on src mac
code --list-extensions > ~/Desktop/vscode-extensions.txt

# import on des mac
cat vscode-extensions.txt | xargs -L 1 code --install-extension

