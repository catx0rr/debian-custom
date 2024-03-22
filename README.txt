


# Install the debian build script to minimal installs or WSL instance of debian


Install all tools directly via curl:

```
curl -sSf https://raw.githubusercontent.com/catx0rr/debian-custom/master/build.sh | sudo bash
```

Install separate tools per functionality:

1. Modify the script 

```
git clone https://github.com/catx0rr/debian-custom
cd debian-custom
nano build.sh
```

```
# install tools per functionality
web_tools=0
internal_tools=1
legacy_tools=0
```

2. Run

```
./install.sh | bash
```