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

# October 17 update

The base image for this repository is the official 2023.2.0 release (with zpm support). 
The current 2023.3 Developer Preview release includes a few enhancements to Foreign Tables and Columnar Storage that will be referred to in the exercises. If you notice this before you travel to Cannes, or if you find that the hotel wifi is not as humble as we think, you can switch to the `intersystemsdc/iris-ml-community:preview` base image by swapping between the two `ARG` lines at the top of the `Dockerfile`. Note that another update to this preview image is expected later this week, which means rebuilding the image after that date will pull that updated image again (unfortunately we don't keep full build number tags for previews). Either image will work for completing the exercises, you'll just see a few things work better (as per their query plans) when you're on' 2023.3.