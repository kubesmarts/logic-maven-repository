# Logic Maven Repository

This repository serves as a GitHub Packages-based Maven repository for Logic artifacts. It contains built Maven artifacts (JARs, source JARs, and other standard Maven artifacts) from the Logic ecosystem.

## Purpose

This repository provides a centralized location for accessing Logic Maven artifacts that may not be available in Maven Central or require specific versions. The artifacts are automatically built and deployed via GitHub Actions workflows.

## Using as a Maven Repository

### Prerequisites

Since this repository uses GitHub Packages, you need to authenticate with a GitHub Personal Access Token (PAT) to access the packages.

#### Creating a Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token" → "Generate new token (classic)"
3. Give your token a descriptive name (e.g., "Maven GitHub Packages")
4. Select the `read:packages` scope (required to download packages)
5. Click "Generate token" and copy the token immediately (you won't be able to see it again)

For more information, see [GitHub's documentation on creating a personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token).

### Configuration

#### 1. Configure Maven Settings

Add the following to your `~/.m2/settings.xml` file:

```xml
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  
  <servers>
    <server>
      <!-- github is the repository ID used directly in Logic code repositories. 
           So for building some of the code repositories using the published snapshots, 
           it is enough to have only the <servers> section in the settings.xml. -->
      <id>github</id>
      <username>YOUR_GITHUB_USERNAME</username>
      <password>YOUR_GITHUB_PERSONAL_ACCESS_TOKEN</password>
    </server>
  </servers>

  <profiles>
    <profile>
      <id>github</id>
      <repositories>
        <repository>
          <id>github</id>
          <url>https://maven.pkg.github.com/kubesmarts/logic-maven-repository</url>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>github</activeProfile>
  </activeProfiles>
</settings>
```

**Important:** Replace `YOUR_GITHUB_USERNAME` with your GitHub username and `YOUR_GITHUB_PERSONAL_ACCESS_TOKEN` with the token you created in the prerequisites step.

**Security Note:** Never commit your `settings.xml` file with your personal access token to version control. Keep it secure on your local machine.

#### 2. Use in Your Project

Once configured, you can add Logic dependencies to your `pom.xml`:

```xml
<dependencies>
  <dependency>
    <groupId>groupIdOfTheDependency</groupId>
    <artifactId>artifactIdOfTheDependency</artifactId>
    <version>YOUR_DESIRED_VERSION</version>
  </dependency>
  <!-- Add other Logic dependencies as needed -->
</dependencies>
```

### Alternative: Project-Level Configuration

You can also configure the repository directly in your project's `pom.xml`:

```xml
<repositories>
  <repository>
    <id>github</id>
    <url>https://maven.pkg.github.com/kubesmarts/logic-maven-repository</url>
    <snapshots>
      <enabled>true</enabled>
    </snapshots>
  </repository>
</repositories>
```

**Note:** Even with project-level repository configuration, you still need to configure authentication in your `~/.m2/settings.xml` file as shown above.

## Available Artifacts

To browse available packages, visit: https://github.com/kubesmarts/logic-maven-repository/packages

## Building and Deploying

Artifacts are built and deployed automatically using GitHub Actions. 

For more information about the build process, see the [workflow configuration](.github/workflows/build-and-deploy-artifacts.yml).

## Troubleshooting

### Authentication Issues

If you receive a 401 Unauthorized error:
- Verify your GitHub username is correct in `settings.xml`
- Ensure your Personal Access Token has the `read:packages` scope
- Check that your token hasn't expired
- Confirm the server `id` in `settings.xml` matches the repository `id`

### Dependency Not Found

If Maven cannot find a dependency:
- Verify the artifact exists in the [packages list](https://github.com/kubesmarts/logic-maven-repository/packages)
- Check that the version number is correct
- Ensure the repository is properly configured in your `settings.xml` or your project
- Confirm you have proper authentication configured (see Authentication Issues above)

## License

The artifacts in this repository are subject to their respective project licenses. Please refer to the individual project repositories for license information.
