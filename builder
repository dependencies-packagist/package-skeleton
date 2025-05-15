#!/usr/bin/env php
<?php

$options = getopt('p::', ['rootPath::']);

(new class ($options) {
    protected string $rootPath;
    protected array $placeholders = [
        ':author_name',
        ':author',
        'author@domain.com',
        ':organization_stud',
        ':organization_slug',
        ':repository_stud',
        ':repository_slug',
        ':vendor_stud',
        ':vendor_slug',
        ':package_stud',
        ':package_slug',
        ':package_description',
        ':YEAR',
    ];

    public function __construct(
        protected array $options = [],
    )
    {
        $this->rootPath = $this->getOption('p', 'rootPath', __DIR__);
    }

    protected function getOption(string $short_option = '', string $long_option = '', mixed $default = null): mixed
    {
        return $this->options[$short_option] ?? $this->options[$long_option] ?? $default;
    }

    public function ask(string $question, string $default = ''): string
    {
        $answer = readline($question . ($default ? " ({$default})" : null) . ' : ');

        if (!$answer) {
            return $default;
        }

        return $answer;
    }

    public function confirm(string $question, bool $default = false): bool
    {
        $answer = $this->ask($question . ' (' . ($default ? 'Y/n' : 'y/N') . ')');

        if (!$answer) {
            return $default;
        }

        return strtolower($answer) === 'y';
    }

    public function writeln(string $line): void
    {
        echo $line . PHP_EOL;
    }

    public function shellExec(string $command): string
    {
        return trim((string) shell_exec($command));
    }

    /**
     * @param string $subject
     * @param string $search
     *
     * @return string
     * @example
     *         strLast('app/Controllers/HomeController.php', '/')
     *         => HomeController.php
     */
    public function strLast(string $subject, string $search): string
    {
        $pos = strrpos($subject, $search);

        if ($pos === false) {
            return $subject;
        }

        return substr($subject, $pos + strlen($search));
    }

    /**
     * @param string $subject
     *
     * @return string
     * @example
     *         slugify("Hello World!")
     *         => hello-world
     */
    public function slugify(string $subject): string
    {
        return strtolower(trim(preg_replace('/[^A-Za-z0-9-]+/', '-', $subject), '-'));
    }

    /**
     * @param string $subject
     *
     * @return string
     * @example
     *         studly("hello-world")
     *         => HelloWorld
     */
    public function studly(string $subject): string
    {
        return str_replace(' ', '', ucwords(str_replace(['-', '_'], ' ', $subject)));
    }

    /**
     * @param string $subject
     * @param string $replace
     *
     * @return string
     * @example
     *         normalizeSeparator("hello-world")
     *         => hello_world
     */
    public function normalizeSeparator(string $subject, string $replace = '_'): string
    {
        return str_replace(['-', '_'], $replace, $subject);
    }

    /**
     * @param string $prefix
     * @param string $content
     *
     * @return string
     * @example
     *         withoutPrefix('hello-', 'hello-world')
     *         => world
     */
    public function withoutPrefix(string $prefix, string $content): string
    {
        if (str_starts_with($content, $prefix)) {
            return substr($content, strlen($prefix));
        }

        return $content;
    }

    public function normalizePath(string $path): string
    {
        return str_replace('/', DIRECTORY_SEPARATOR, $path);
    }

    public function replaceStringsInFile(string $file, array $replacements): void
    {
        $contents = file_get_contents($file);

        file_put_contents(
            $file,
            str_replace(
                array_keys($replacements),
                array_values($replacements),
                $contents
            )
        );
    }

    private function getComposerFile(): string
    {
        return $this->rootPath . '/composer.json';
    }

    public function removeDevDependencies(array|string $names, bool $dev = true): void
    {
        $data = json_decode(file_get_contents($this->getComposerFile()), true);

        foreach ($dev ? $data['require-dev'] : $data['require'] as $name => $version) {
            if (in_array($name, (array) $names, true)) {
                unset($data['require-dev'][$name]);
            }
        }

        file_put_contents($this->getComposerFile(), json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }

    public function removeScripts(array|string $scriptName): void
    {
        $data = json_decode(file_get_contents($this->getComposerFile()), true);

        foreach ($data['scripts'] as $name => $script) {
            if ($scriptName === $name) {
                unset($data['scripts'][$name]);
                break;
            }
        }

        file_put_contents($this->getComposerFile(), json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    }

    public function removeParagraphs(string $file): void
    {
        $contents = file_get_contents($file);

        file_put_contents(
            $file,
            preg_replace('/<!--delete-->.*?<!--\/delete-->/s', '', $contents) ?: $contents
        );
    }


    public function deleteFileIfExists(string $filename): void
    {
        if (file_exists($filename) && is_file($filename)) {
            unlink($filename);
        }
    }

    public function deleteDirectoryIfExists(string $dirname): void
    {
        if (file_exists($dirname) && is_dir($dirname)) {
            $items = array_diff(scandir($dirname), ['.', '..']);
            foreach ($items as $item) {
                $path = $dirname . DIRECTORY_SEPARATOR . $item;
                is_dir($path) ? $this->deleteDirectoryIfExists($path) : $this->deleteFileIfExists($path);
            }
            rmdir($dirname);
        }
    }

    public function replaceForWindows(): array
    {
        $placeholders = implode(' ', $this->placeholders);
        $file = basename(__FILE__);
        $commands = [
            'dir /S /B *',
            'findstr /v /i .git\\',
            'findstr /v /i vendor',
            "findstr /v /i {$file}",
            'findstr /r /i /M /F:/ "' . $placeholders . '"',
        ];
        $command = implode('|', $commands);
        return preg_split('/\\r\\n|\\r|\\n/', $this->shellExec($command));
    }

    public function replaceForAllOtherOSes(): array
    {
        $placeholders = implode('|', $this->placeholders);
        $file = basename(__FILE__);
        $commands = [
            "grep -E -r -l -i '{$placeholders}' --exclude-dir=vendor ./* ./.github/* ",
            "grep -v {$file}",
        ];
        $command = implode('|', $commands);
        return explode(PHP_EOL, $this->shellExec($command));
    }

    public function getModifyFiles(): array
    {
        return str_starts_with(strtoupper(PHP_OS), 'WIN') ? $this->replaceForWindows() : $this->replaceForAllOtherOSes();
    }

    protected function getGitHubApiEndpoint(string $endpoint): ?stdClass
    {
        try {
            $curl = curl_init("https://api.github.com/{$endpoint}");
            curl_setopt_array($curl, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTPGET => true,
                CURLOPT_HTTPHEADER => [
                    'User-Agent: dependencies-packagist/package-skeleton/1.0.0',
                ],
            ]);
            $response = curl_exec($curl);
            $statusCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
            curl_close($curl);

            if ($statusCode === 200) {
                return json_decode($response);
            }
        } catch (Exception $e) {
            // ignore
        }

        return null;
    }

    protected function fromCommitsForGitHubUsername(): string
    {
        $authorName = strtolower($this->shellExec('git config user.name'));

        $committersRaw = $this->shellExec("git log --author='@users.noreply.github.com' --pretty='%an:%ae' --reverse");
        $committersLines = explode("\n", $committersRaw);
        $committers = array_filter(array_map(function ($line) use ($authorName) {
            $line = trim($line);
            [$name, $email] = explode(':', $line) + [null, null];

            return [
                'name' => $name,
                'email' => $email,
                'isMatch' => strtolower($name) === $authorName && !str_contains($name, '[bot]'),
            ];
        }, $committersLines), fn($item) => $item['isMatch']);

        if (empty($committers)) {
            return '';
        }

        $firstCommitter = reset($committers);

        return explode('@', $firstCommitter['email'])[0] ?? '';
    }

    protected function guessGitHubUsernameUsingCli(): string
    {
        try {
            if (preg_match('/Logged in to github.com account ([a-zA-Z-_]+).+/', $this->shellExec('gh auth status -h github.com 2>&1'), $matches)) {
                return $matches[1];
            }
        } catch (Exception $e) {
            // ignore
        }

        return '';
    }

    public function guessGitHubUsername(): string
    {
        $username = $this->fromCommitsForGitHubUsername();
        if (!empty($username)) {
            return $username;
        }

        $username = $this->guessGitHubUsernameUsingCli();
        if (!empty($username)) {
            return $username;
        }

        // fall back to using the username from the git remote
        $remoteUrl = $this->shellExec('git config remote.origin.url');
        $remoteUrlParts = explode('/', str_replace(':', '/', trim($remoteUrl)));

        return $remoteUrlParts[1] ?? '';
    }

    public function guessGitHubUrlInfo(string $authorName, string $username): array
    {
        $remoteUrl = $this->shellExec('git config remote.origin.url');
        $remoteUrlParts = explode('/', str_replace(':', '/', trim($remoteUrl)));

        if (!isset($remoteUrlParts[1])) {
            return [$authorName, $username];
        }

        $response = $this->getGitHubApiEndpoint("orgs/{$remoteUrlParts[1]}");

        if ($response === null) {
            return [$authorName, $username];
        }

        return [$response->name ?? $authorName, $response->login ?? $username];
    }

    public function __invoke(): void
    {
        $gitName = $this->shellExec('git config user.name');
        $authorName = $this->ask('Author name', $gitName);//

        $gitEmail = $this->shellExec('git config user.email');
        $authorEmail = $this->ask('Author email', $gitEmail);//
        $authorUsername = $this->ask('Author username', $this->guessGitHubUsername());//

        $folderName = basename(__DIR__);
        [$organizationName, $organizationUsername] = $this->guessGitHubUrlInfo($authorName, $authorUsername);

        $organizationName = $this->ask('Organization name for https://github.com/:organization_slug', $organizationUsername ?? $this->slugify($organizationName));//
        $organizationSlug = $this->slugify($organizationName);//
        $organizationStud = $this->studly($organizationName);//

        $repositoryName = $this->ask("Repository name for https://github.com/{$organizationSlug}/:repository_slug", $folderName);
        $repositorySlug = $this->slugify($repositoryName);
        $repositoryStud = $this->studly($repositoryName);

        $vendorName = $this->ask('Vendor name for https://packagist.org/packages/:vendor_slug', $organizationSlug);
        $vendorSlug = $this->slugify($vendorName);
        $vendorStud = $this->studly($vendorName);

        $packageName = $this->ask("Package name for https://packagist.org/packages/{$vendorSlug}/:package_slug", $folderName);
        $packageSlug = $this->slugify($packageName);
        $packageStud = $this->studly($packageName);
        $description = $this->ask('Package description', "This is my package {$packageSlug}");

        $useBugReport = $this->confirm('Enable Bug Report?', false);
        $useDependabot = $this->confirm('Enable Dependabot?', false);
        $useUpdateChangelogWorkflow = $this->confirm('Use automatic changelog updater workflow?', false);
        $useGitHubSponsor = $this->confirm('Enable GitHub Sponsors?', false);

        $this->writeln('------');
        $this->writeln("Author                  : {$authorName} ({$authorUsername}, {$authorEmail})");
        $this->writeln("Organization            : {$organizationStud} <https://github.com/{$organizationSlug}>");
        $this->writeln("Repository              : {$repositoryStud} <https://github.com/{$organizationSlug}/{$repositorySlug}>");
        $this->writeln("Vendor                  : {$vendorSlug} <https://packagist.org/packages/{$vendorSlug}>");
        $this->writeln("Package                 : {$packageSlug} <https://packagist.org/packages/{$vendorSlug}/{$packageSlug}>");
        $this->writeln("Package description     : {$description}");
        $this->writeln("Namespace               : {$vendorStud}\\{$packageStud}");
        $this->writeln('---');
        $this->writeln('Packages & Utilities');
        $this->writeln('Use Bug Report          : ' . ($useBugReport ? 'yes' : 'no'));
        $this->writeln('Use Dependabot          : ' . ($useDependabot ? 'yes' : 'no'));
        $this->writeln('Use Auto-Changelog      : ' . ($useUpdateChangelogWorkflow ? 'yes' : 'no'));
        $this->writeln('Use GitHub Sponsors     : ' . ($useGitHubSponsor ? 'yes' : 'no'));
        $this->writeln('------');
        $this->writeln('This script will replace the above values in all relevant files in the project directory.');

        if (!$this->confirm('Modify files?', true)) {
            exit(1);
        }

        foreach ($this->getModifyFiles() as $file) {
            $this->replaceStringsInFile($file, [
                ':author_name' => $authorName,
                ':author' => $authorUsername,
                'author@domain.com' => $authorEmail,
                ':organization_stud' => $organizationStud,
                ':organization_slug' => $organizationSlug,
                ':repository_stud' => $repositoryStud,
                ':repository_slug' => $repositorySlug,
                ':vendor_stud' => $vendorStud,
                ':vendor_slug' => $vendorSlug,
                ':package_stud' => $packageStud,
                ':package_slug' => $packageSlug,
                ':package_description' => $description,
                ':YEAR' => date('Y'),
            ]);


            match (true) {
                str_ends_with($file, $this->normalizePath('src/Skeleton.php')) => rename($file, $this->normalizePath('src/' . $packageStud . '.php')),
                str_ends_with($file, 'README.md') => $this->removeParagraphs($file),
                default => [],
            };
        }

        if (!$useBugReport) {
            $this->deleteFileIfExists(__DIR__ . '/.github/ISSUE_TEMPLATE/bug.yml');
        }

        if (!$useDependabot) {
            $this->deleteFileIfExists(__DIR__ . '/.github/dependabot.yml');
        }

        if (!$useUpdateChangelogWorkflow) {
            $this->deleteFileIfExists(__DIR__ . '/.github/workflows/update-changelog.yml');
        }

        if (!$useGitHubSponsor) {
            $this->deleteFileIfExists(__DIR__ . '/.github/FUNDING.yml');
        }

        if (!$useBugReport && !$useDependabot && !$useUpdateChangelogWorkflow && !$useGitHubSponsor) {
            $this->deleteDirectoryIfExists(__DIR__ . '/.github');
        }

        if ($this->confirm('Let this script delete itself?', true)) {
            $this->deleteFileIfExists(__FILE__);
        }

        $this->writeln('successfully.');
    }
})();
