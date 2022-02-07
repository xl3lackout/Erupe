# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

from collections import defaultdict
import functools
import os
import re
import pathlib
import shelve
import warnings

from git import Repo
from jira import JIRA
from semver import VersionInfo as SemVer

from .utils.source import ArrowSources
from .utils.report import JinjaReport


def cached_property(fn):
    return property(functools.lru_cache(maxsize=1)(fn))


class Version(SemVer):

    __slots__ = ('released', 'release_date')

    def __init__(self, released=False, release_date=None, **kwargs):
        super().__init__(**kwargs)
        self.released = released
        self.release_date = release_date

    @classmethod
    def parse(cls, version, **kwargs):
        return cls(**SemVer.parse(version).to_dict(), **kwargs)

    @classmethod
    def from_jira(cls, jira_version):
        return cls.parse(
            jira_version.name,
            released=jira_version.released,
            release_date=getattr(jira_version, 'releaseDate', None)
        )


class Issue:

    def __init__(self, key, type, summary):
        self.key = key
        self.type = type
        self.summary = summary

    @classmethod
    def from_jira(cls, jira_issue):
        return cls(
            key=jira_issue.key,
            type=jira_issue.fields.issuetype.name,
            summary=jira_issue.fields.summary
        )

    @property
    def project(self):
        return self.key.split('-')[0]

    @property
    def number(self):
        return int(self.key.split('-')[1])


class Jira(JIRA):

    def __init__(self, user=None, password=None,
                 url='https://issues.apache.org/jira'):
        user = user or os.environ.get('APACHE_JIRA_USER')
        password = password or os.environ.get('APACHE_JIRA_PASSWORD')
        super().__init__(url, basic_auth=(user, password))

    def project_version(self, version_string, project='ARROW'):
        # query version from jira to populated with additional metadata
        versions = {str(v): v for v in self.project_versions(project)}
        return versions[version_string]

    def project_versions(self, project):
        versions = []
        for v in super().project_versions(project):
            try:
                versions.append(Version.from_jira(v))
            except ValueError:
                # ignore invalid semantic versions like JS-0.4.0
                continue
        return sorted(versions, reverse=True)

    def issue(self, key):
        return Issue.from_jira(super().issue(key))

    def project_issues(self, version, project='ARROW'):
        query = "project={} AND fixVersion={}".format(project, version)
        issues = super().search_issues(query, maxResults=False)
        return list(map(Issue.from_jira, issues))


class CachedJira:

    def __init__(self, cache_path, jira=None):
        self.jira = jira or Jira()
        self.cache_path = cache_path

    def __getattr__(self, name):
        attr = getattr(self.jira, name)
        return self._cached(name, attr) if callable(attr) else attr

    def _cached(self, name, method):
        def wrapper(*args, **kwargs):
            key = str((name, args, kwargs))
            with shelve.open(self.cache_path) as cache:
                try:
                    result = cache[key]
                except KeyError:
                    cache[key] = result = method(*args, **kwargs)
            return result
        return wrapper


_TITLE_REGEX = re.compile(
    r"(?P<issue>(?P<project>(ARROW|PARQUET))\-\d+)?\s*:?\s*"
    r"(?P<components>\[.*\])?\s*(?P<summary>.*)"
)
_COMPONENT_REGEX = re.compile(r"\[([^\[\]]+)\]")


class CommitTitle:

    def __init__(self, summary, project=None, issue=None, components=None):
        self.project = project
        self.issue = issue
        self.components = components or []
        self.summary = summary

    def __str__(self):
        out = ""
        if self.issue:
            out += "{}: ".format(self.issue)
        if self.components:
            for component in self.components:
                out += "[{}]".format(component)
            out += " "
        out += self.summary
        return out

    def __eq__(self, other):
        return (
            self.summary == other.summary and
            self.project == other.project and
            self.issue == other.issue and
            self.components == other.components
        )

    def __hash__(self):
        return hash(
            (self.summary, self.project, self.issue, tuple(self.components))
        )

    @classmethod
    def parse(cls, headline):
        matches = _TITLE_REGEX.match(headline)
        if matches is None:
            warnings.warn(
                "Unable to parse commit message `{}`".format(headline)
            )
            return CommitTitle(headline)

        values = matches.groupdict()
        components = values.get('components') or ''
        components = _COMPONENT_REGEX.findall(components)

        return CommitTitle(
            values['summary'],
            project=values.get('project'),
            issue=values.get('issue'),
            components=components
        )


class Commit:

    def __init__(self, wrapped):
        self._title = CommitTitle.parse(wrapped.summary)
        self._wrapped = wrapped

    def __getattr__(self, attr):
        if hasattr(self._title, attr):
            return getattr(self._title, attr)
        else:
            return getattr(self._wrapped, attr)

    def __repr__(self):
        template = '<Commit sha={!r} issue={!r} components={!r} summary={!r}>'
        return template.format(self.hexsha, self.issue, self.components,
                               self.summary)

    @property
    def url(self):
        return 'https://github.com/apache/arrow/commit/{}'.format(self.hexsha)

    @property
    def title(self):
        return self._title


class ReleaseCuration(JinjaReport):
    templates = {
        'console': 'release_curation.txt.j2'
    }
    fields = [
        'release',
        'within',
        'outside',
        'nojira',
        'parquet',
        'nopatch'
    ]


class JiraChangelog(JinjaReport):
    templates = {
        'markdown': 'release_changelog.md.j2',
        'html': 'release_changelog.html.j2'
    }
    fields = [
        'release',
        'categories'
    ]


class Release:

    def __init__(self):
        raise TypeError("Do not initialize Release class directly, use "
                        "Release.from_jira(version) instead.")

    def __repr__(self):
        if self.version.released:
            status = "released_at={!r}".format(self.version.release_date)
        else:
            status = "pending"
        return "<{} {!r} {}>".format(self.__class__.__name__,
                                     str(self.version), status)

    @staticmethod
    def from_jira(version, jira=None, repo=None):
        if jira is None:
            jira = Jira()
        elif isinstance(jira, str):
            jira = Jira(jira)
        elif not isinstance(jira, (Jira, CachedJira)):
            raise TypeError("`jira` argument must be a server url or a valid "
                            "Jira instance")

        if repo is None:
            arrow = ArrowSources.find()
            repo = Repo(arrow.path)
        elif isinstance(repo, (str, pathlib.Path)):
            repo = Repo(repo)
        elif not isinstance(repo, Repo):
            raise TypeError("`repo` argument must be a path or a valid Repo "
                            "instance")

        if isinstance(version, str):
            version = jira.project_version(version, project='ARROW')
        elif not isinstance(version, Version):
            raise TypeError(version)

        # decide the type of the release based on the version number
        if version.patch == 0:
            if version.minor == 0:
                klass = MajorRelease
            elif version.major == 0:
                # handle minor releases before 1.0 as major releases
                klass = MajorRelease
            else:
                klass = MinorRelease
        else:
            klass = PatchRelease

        # prevent instantiating release object directly
        obj = klass.__new__(klass)
        obj.version = version
        obj.jira = jira
        obj.repo = repo

        return obj

    @property
    def is_released(self):
        return self.version.released

    @property
    def tag(self):
        return "apache-arrow-{}".format(str(self.version))

    @property
    def branch(self):
        raise NotImplementedError()

    @property
    def siblings(self):
        """
        Releases to consider when calculating previous and next releases.
        """
        raise NotImplementedError()

    @cached_property
    def previous(self):
        # select all non-patch releases
        position = self.siblings.index(self.version)
        try:
            previous = self.siblings[position + 1]
        except IndexError:
            # first release doesn't have a previous one
            return None
        else:
            return Release.from_jira(previous, jira=self.jira, repo=self.repo)

    @cached_property
    def next(self):
        # select all non-patch releases
        position = self.siblings.index(self.version)
        if position <= 0:
            raise ValueError("There is no upcoming release set in JIRA after "
                             "version {}".format(self.version))
        upcoming = self.siblings[position - 1]
        return Release.from_jira(upcoming, jira=self.jira, repo=self.repo)

    @cached_property
    def issues(self):
        issues = self.jira.project_issues(self.version, project='ARROW')
        return {i.key: i for i in issues}

    @cached_property
    def commits(self):
        """
        All commits applied between two versions.
        """
        if self.previous is None:
            # first release
            lower = ''
        else:
            lower = self.repo.tags[self.previous.tag]

        if self.version.released:
            upper = self.repo.tags[self.tag]
        else:
            try:
                upper = self.repo.branches[self.branch]
            except IndexError:
                warnings.warn("Release branch `{}` doesn't exist."
                              .format(self.branch))
                return []

        commit_range = "{}..{}".format(lower, upper)
        return list(map(Commit, self.repo.iter_commits(commit_range)))

    def curate(self):
        # handle commits with parquet issue key specially and query them from
        # jira and add it to the issues
        release_issues = self.issues

        within, outside, nojira, parquet = [], [], [], []
        for c in self.commits:
            if c.issue is None:
                nojira.append(c)
            elif c.issue in release_issues:
                within.append((release_issues[c.issue], c))
            elif c.project == 'PARQUET':
                parquet.append((self.jira.issue(c.issue), c))
            else:
                outside.append((self.jira.issue(c.issue), c))

        # remaining jira tickets
        within_keys = {i.key for i, c in within}
        nopatch = [issue for key, issue in release_issues.items()
                   if key not in within_keys]

        return ReleaseCuration(release=self, within=within, outside=outside,
                               nojira=nojira, parquet=parquet, nopatch=nopatch)

    def changelog(self):
        release_issues = []

        # get organized report for the release
        curation = self.curate()

        # jira tickets having patches in the release
        for issue, _ in curation.within:
            release_issues.append(issue)

        # jira tickets without patches
        for issue in curation.nopatch:
            release_issues.append(issue)

        # parquet patches in the release
        for issue, _ in curation.parquet:
            release_issues.append(issue)

        # organize issues into categories
        issue_types = {
            'Bug': 'Bug Fixes',
            'Improvement': 'New Features and Improvements',
            'New Feature': 'New Features and Improvements',
            'Sub-task': 'New Features and Improvements',
            'Task': 'New Features and Improvements',
            'Test': 'Bug Fixes',
            'Wish': 'New Features and Improvements',
        }
        categories = defaultdict(list)
        for issue in release_issues:
            categories[issue_types[issue.type]].append(issue)

        # sort issues by the issue key in ascending order
        for name, issues in categories.items():
            issues.sort(key=lambda issue: (issue.project, issue.number))

        return JiraChangelog(release=self, categories=categories)


class MaintenanceMixin:
    """
    Utility methods for cherry-picking commits from the main branch.
    """

    def commits_to_pick(self, exclude_already_applied=True):
        # collect commits applied on the main branch since the root of the
        # maintenance branch (the previous major release)
        if self.version.major == 0:
            # treat minor releases as major releases preceeding 1.0.0 release
            commit_range = "apache-arrow-0.{}.0..master".format(
                self.version.minor
            )
        else:
            commit_range = "apache-arrow-{}.0.0..master".format(
                self.version.major
            )

        # keeping the original order of the commits helps to minimize the merge
        # conflicts during cherry-picks
        commits = map(Commit, self.repo.iter_commits(commit_range))

        # exclude patches that have been already applied to the maintenance
        # branch, we cannot identify patches based on sha because it changes
        # after the cherry pick so use commit title instead
        if exclude_already_applied:
            already_applied = {c.title for c in self.commits}
        else:
            already_applied = set()

        # iterate over the commits applied on the main branch and filter out
        # the ones that are included in the jira release
        patches_to_pick = [c for c in commits if
                           c.issue in self.issues and
                           c.title not in already_applied]

        return reversed(patches_to_pick)

    def cherry_pick_commits(self, recreate_branch=True):
        if recreate_branch:
            # delete, create and checkout the maintenance branch based off of
            # the previous tag
            if self.branch in self.repo.branches:
                self.repo.git.branch('-D', self.branch)
            self.repo.git.checkout(self.previous.tag, b=self.branch)
        else:
            # just checkout the already existing maintenance branch
            self.repo.git.checkout(self.branch)

        # cherry pick the commits based on the jira tickets
        for commit in self.commits_to_pick():
            self.repo.git.cherry_pick(commit.hexsha)


class MajorRelease(Release):

    @property
    def branch(self):
        return "master"

    @cached_property
    def siblings(self):
        """
        Filter only the major releases.
        """
        # handle minor releases before 1.0 as major releases
        return [v for v in self.jira.project_versions('ARROW')
                if v.patch == 0 and (v.major == 0 or v.minor == 0)]


class MinorRelease(Release, MaintenanceMixin):

    @property
    def branch(self):
        return "maint-{}.x.x".format(self.version.major)

    @cached_property
    def siblings(self):
        """
        Filter the major and minor releases.
        """
        return [v for v in self.jira.project_versions('ARROW') if v.patch == 0]


class PatchRelease(Release, MaintenanceMixin):

    @property
    def branch(self):
        return "maint-{}.{}.x".format(self.version.major, self.version.minor)

    @cached_property
    def siblings(self):
        """
        No filtering, consider all releases.
        """
        return self.jira.project_versions('ARROW')
