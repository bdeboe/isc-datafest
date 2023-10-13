# International SE Summit setup

*If you're attending the International SE Summit in Cannes, please perform the following steps -before you head to France-, and report any issues in the [Teams groups](https://teams.microsoft.com/l/team/19%3aWzHrEUOghpB5SaqGUCg4Ww_3uxkZusqdhpthY4kbtIQ1%40thread.tacv2/conversations?groupId=2e6e4258-40ef-46de-aaaf-c175df4362a3&tenantId=74abaa74-2829-4279-b25c-5743687b0bf5)*

First download this repository's contents using `git clone` or by downloading as a zip and extracting to a folder of your choice. 
Then, making sure you are in the repository's root directory (`isc-datafest`), run the following to build the image:

```Shell
docker build --tag iris-datafest .
```
or
```Shell
docker-compose build
```

We may still change the image slightly, but if you've built it once, you'll have cached the most important layers (base image & python package installation) and rebuilding the changes it should not take long or much bandwidth. 