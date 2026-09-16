#!/usr/bin/env node
/**
 * Generates dist/streak-stats.svg — the contribution-streak card shown on the
 * GitHub profile README — from the GitHub GraphQL API with a personal token,
 * so the card no longer depends on rate-limited third-party services.
 *
 * Usage:
 *   node scripts/build-streak.js            # needs GH_TOKEN env (classic PAT, read:user scope)
 *   node scripts/build-streak.js --demo     # render with fixture data, no token needed
 *   node scripts/build-streak.js --out path # write SVG to a custom path
 */
"use strict";

const fs = require("fs");
const path = require("path");

const GRAPHQL_URL = "https://api.github.com/graphql";
const MIN_YEAR = 2005;

const THEME = {
  width: 495,
  height: 195,
  radius: 12,
  background: "#050816",
  border: "#312E81",
  divider: "#312E81",
  ring: "#7C3AED",
  fire: "#22D3EE",
  currStreakNum: "#E2E8F0",
  sideNums: "#E2E8F0",
  currStreakLabel: "#22D3EE",
  sideLabels: "#A78BFA",
  dates: "#94A3B8",
  fontFamily: '"Segoe UI", Ubuntu, sans-serif',
};

const YEAR_QUERY = `
query($user: String!, $from: DateTime!, $to: DateTime!) {
  user(login: $user) {
    createdAt
    contributionsCollection(from: $from, to: $to) {
      contributionYears
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount } }
      }
    }
  }
}`;

function addDaysKey(key, days) {
  const d = new Date(`${key}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

async function withRetry(fn, attempts = 2) {
  let lastError;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      if (i < attempts - 1) await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
  throw lastError;
}

async function graphqlRequest(token, variables) {
  const res = await fetch(GRAPHQL_URL, {
    method: "POST",
    headers: {
      Authorization: `bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      "User-Agent": "repan334-streak-card",
    },
    body: JSON.stringify({ query: YEAR_QUERY, variables }),
  });
  if (!res.ok) {
    throw new Error(`GitHub GraphQL responded with HTTP ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  if (json.errors && json.errors.length > 0) {
    throw new Error(`GitHub GraphQL errors: ${json.errors.map((e) => e.message).join("; ")}`);
  }
  if (!json.data || !json.data.user) {
    throw new Error("GitHub GraphQL returned no user data.");
  }
  return json.data;
}

async function fetchContributionDays(token, user) {
  const currentYear = new Date().getUTCFullYear();

  const first = await withRetry(() =>
    graphqlRequest(token, {
      user,
      from: `${currentYear}-01-01T00:00:00Z`,
      to: `${currentYear}-12-31T23:59:59Z`,
    })
  );

  const createdYear = Number(String(first.user.createdAt).slice(0, 4));
  const contributionYears = first.user.contributionsCollection.contributionYears || [];
  const firstContributionYear = Math.min(createdYear, ...contributionYears.map(Number));
  const startYear = Math.max(MIN_YEAR, firstContributionYear);

  const responses = [first];
  for (let year = startYear; year < currentYear; year++) {
    responses.push(
      await withRetry(() =>
        graphqlRequest(token, {
          user,
          from: `${year}-01-01T00:00:00Z`,
          to: `${year}-12-31T23:59:59Z`,
        })
      )
    );
  }

  const byDate = new Map();
  for (const data of responses) {
    const weeks = data.user.contributionsCollection.contributionCalendar.weeks || [];
    for (const week of weeks) {
      for (const day of week.contributionDays) {
        byDate.set(day.date, day.contributionCount);
      }
    }
  }
  if (byDate.size === 0) {
    throw new Error("GitHub returned no contribution data — check that GH_TOKEN has read:user scope.");
  }
  return byDate;
}

function computeStats(byDate, todayKey) {
  const total = [...byDate.values()].reduce((sum, v) => sum + v, 0);
  const contributed = [...byDate.keys()].filter((k) => byDate.get(k) > 0).sort();

  let longest = 0;
  let longestStart = null;
  let longestEnd = null;
  let run = 0;
  let runStart = null;
  for (let i = 0; i < contributed.length; i++) {
    const key = contributed[i];
    if (i > 0 && key === addDaysKey(contributed[i - 1], 1)) {
      run++;
    } else {
      if (run > longest) {
        longest = run;
        longestStart = runStart;
        longestEnd = contributed[i - 1];
      }
      run = 1;
      runStart = key;
    }
  }
  if (run > longest) {
    longest = run;
    longestStart = runStart;
    longestEnd = contributed[contributed.length - 1];
  }

  let cursor = todayKey;
  if ((byDate.get(cursor) || 0) === 0) cursor = addDaysKey(cursor, -1);
  let current = 0;
  let currentStart = null;
  let currentEnd = null;
  while ((byDate.get(cursor) || 0) > 0) {
    if (current === 0) currentEnd = cursor;
    currentStart = cursor;
    current++;
    cursor = addDaysKey(cursor, -1);
  }

  return {
    total,
    current,
    currentStart,
    currentEnd,
    longest,
    longestStart,
    longestEnd,
    firstContribution: contributed[0] || null,
  };
}

function demoData() {
  const byDate = new Map();
  const todayKey = "2026-09-16";
  const start = new Date("2024-12-21T00:00:00Z");
  const d = new Date(start);
  let i = 0;
  while (d.toISOString().slice(0, 10) <= todayKey) {
    const key = d.toISOString().slice(0, 10);
    let count = 0;
    if (key >= "2025-08-26" && key <= "2025-08-31") {
      count = 1 + (i % 3);
    } else if (key >= "2026-09-13" && key <= "2026-09-15") {
      count = 1 + (i % 3);
    } else if (key === "2025-08-25" || key === "2025-09-01" || key === "2026-09-12" || key === todayKey) {
      count = 0;
    } else if (i % 3 !== 2) {
      count = 1 + (i % 2);
    }
    byDate.set(key, count);
    d.setUTCDate(d.getUTCDate() + 1);
    i++;
  }
  return { byDate, todayKey };
}

function formatDay(key, { withYear } = {}) {
  const opts = { month: "short", day: "numeric", timeZone: "UTC" };
  if (withYear) opts.year = "numeric";
  return new Intl.DateTimeFormat("en-US", opts).format(new Date(`${key}T00:00:00Z`));
}

function formatRange(startKey, endKey) {
  if (!startKey || !endKey) return "No active streak";
  if (startKey.slice(0, 4) === endKey.slice(0, 4)) {
    return `${formatDay(startKey)} - ${formatDay(endKey)}`;
  }
  return `${formatDay(startKey, { withYear: true })} - ${formatDay(endKey, { withYear: true })}`;
}

function escapeXml(value) {
  return String(value).replace(/[<>&'"]/g, (c) => {
    return { "<": "&lt;", ">": "&gt;", "&": "&amp;", "'": "&apos;", '"': "&quot;" }[c];
  });
}

function renderSvg(stats) {
  const t = THEME;
  const total = stats.total.toLocaleString("en-US");
  const current = stats.current.toLocaleString("en-US");
  const longest = stats.longest.toLocaleString("en-US");
  const totalRange = stats.firstContribution
    ? `${formatDay(stats.firstContribution, { withYear: true })} - Present`
    : "No contributions yet";
  const currentRange = stats.current > 0 ? formatRange(stats.currentStart, stats.currentEnd) : "No active streak";
  const longestRange = stats.longest > 0 ? formatRange(stats.longestStart, stats.longestEnd) : "No active streak";

  return `<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'
                style='isolation: isolate' viewBox='0 0 ${t.width} ${t.height}' width='${t.width}px' height='${t.height}px' direction='ltr'>
        <style>
            @keyframes currstreak {
                0% { font-size: 3px; opacity: 0.2; }
                80% { font-size: 34px; opacity: 1; }
                100% { font-size: 28px; opacity: 1; }
            }
            @keyframes fadein {
                0% { opacity: 0; }
                100% { opacity: 1; }
            }
        </style>
        <defs>
            <clipPath id='outer_rectangle'>
                <rect width='${t.width}' height='${t.height}' rx='${t.radius}'/>
            </clipPath>
            <mask id='mask_out_ring_behind_fire'>
                <rect width='${t.width}' height='${t.height}' fill='white'/>
                <ellipse id='mask-ellipse' cx='247.5' cy='32' rx='13' ry='18' fill='black'/>
            </mask>
        </defs>
        <g clip-path='url(#outer_rectangle)'>
            <g style='isolation: isolate'>
                <rect stroke='${t.border}' fill='${t.background}' rx='${t.radius}' x='0.5' y='0.5' width='${t.width - 1}' height='${t.height - 1}'/>
            </g>
            <g style='isolation: isolate'>
                <line x1='165' y1='28' x2='165' y2='170' vector-effect='non-scaling-stroke' stroke-width='1' stroke='${t.divider}' stroke-linejoin='miter' stroke-linecap='square' stroke-miterlimit='3'/>
                <line x1='330' y1='28' x2='330' y2='170' vector-effect='non-scaling-stroke' stroke-width='1' stroke='${t.divider}' stroke-linejoin='miter' stroke-linecap='square' stroke-miterlimit='3'/>
            </g>
            <g style='isolation: isolate'>
                <g transform='translate(82.5, 48)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.sideNums}' stroke='none' font-family='${t.fontFamily}' font-weight='700' font-size='28px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 0.6s'>
                        ${escapeXml(total)}
                    </text>
                </g>
                <g transform='translate(82.5, 84)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.sideLabels}' stroke='none' font-family='${t.fontFamily}' font-weight='400' font-size='14px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 0.7s'>
                        Total Contributions
                    </text>
                </g>
                <g transform='translate(82.5, 114)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.dates}' stroke='none' font-family='${t.fontFamily}' font-weight='400' font-size='12px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 0.8s'>
                        ${escapeXml(totalRange)}
                    </text>
                </g>
            </g>
            <g style='isolation: isolate'>
                <g transform='translate(247.5, 108)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.currStreakLabel}' stroke='none' font-family='${t.fontFamily}' font-weight='700' font-size='14px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 0.9s'>
                        Current Streak
                    </text>
                </g>
                <g transform='translate(247.5, 145)'>
                    <text x='0' y='21' stroke-width='0' text-anchor='middle' fill='${t.dates}' stroke='none' font-family='${t.fontFamily}' font-weight='400' font-size='12px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 0.9s'>
                        ${escapeXml(currentRange)}
                    </text>
                </g>
                <g mask='url(#mask_out_ring_behind_fire)'>
                    <circle cx='247.5' cy='71' r='40' fill='none' stroke='${t.ring}' stroke-width='5' style='opacity: 0; animation: fadein 0.5s linear forwards 0.4s'></circle>
                </g>
                <g transform='translate(247.5, 19.5)' stroke-opacity='0' style='opacity: 0; animation: fadein 0.5s linear forwards 0.6s'>
                    <path d='M -12 -0.5 L 15 -0.5 L 15 23.5 L -12 23.5 L -12 -0.5 Z' fill='none'/>
                    <path d='M 1.5 0.67 C 1.5 0.67 2.24 3.32 2.24 5.47 C 2.24 7.53 0.89 9.2 -1.17 9.2 C -3.23 9.2 -4.79 7.53 -4.79 5.47 L -4.76 5.11 C -6.78 7.51 -8 10.62 -8 13.99 C -8 18.41 -4.42 22 0 22 C 4.42 22 8 18.41 8 13.99 C 8 8.6 5.41 3.79 1.5 0.67 Z M -0.29 19 C -2.07 19 -3.51 17.6 -3.51 15.86 C -3.51 14.24 -2.46 13.1 -0.7 12.74 C 1.07 12.38 2.9 11.53 3.92 10.16 C 4.31 11.45 4.51 12.81 4.51 14.2 C 4.51 16.85 2.36 19 -0.29 19 Z' fill='${t.fire}' stroke-opacity='0'/>
                </g>
                <g transform='translate(247.5, 48)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.currStreakNum}' stroke='none' font-family='${t.fontFamily}' font-weight='700' font-size='28px' font-style='normal' style='animation: currstreak 0.6s linear forwards'>
                        ${escapeXml(current)}
                    </text>
                </g>
            </g>
            <g style='isolation: isolate'>
                <g transform='translate(412.5, 48)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.sideNums}' stroke='none' font-family='${t.fontFamily}' font-weight='700' font-size='28px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 1.2s'>
                        ${escapeXml(longest)}
                    </text>
                </g>
                <g transform='translate(412.5, 84)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.sideLabels}' stroke='none' font-family='${t.fontFamily}' font-weight='400' font-size='14px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 1.3s'>
                        Longest Streak
                    </text>
                </g>
                <g transform='translate(412.5, 114)'>
                    <text x='0' y='32' stroke-width='0' text-anchor='middle' fill='${t.dates}' stroke='none' font-family='${t.fontFamily}' font-weight='400' font-size='12px' font-style='normal' style='opacity: 0; animation: fadein 0.5s linear forwards 1.4s'>
                        ${escapeXml(longestRange)}
                    </text>
                </g>
            </g>
        </g>
    </svg>
`;
}

async function main() {
  const args = process.argv.slice(2);
  const demo = args.includes("--demo");
  const outFlag = args.indexOf("--out");
  const outPath =
    outFlag !== -1 && args[outFlag + 1]
      ? path.resolve(args[outFlag + 1])
      : path.join(__dirname, "..", "dist", "streak-stats.svg");

  let byDate;
  let todayKey;
  if (demo) {
    ({ byDate, todayKey } = demoData());
  } else {
    const token = process.env.GH_TOKEN;
    const user = process.env.STREAK_USER || "repan334";
    if (!token) {
      throw new Error(
        "GH_TOKEN environment variable is required. Create a classic PAT with read:user scope and add it as the GH_TOKEN repository secret."
      );
    }
    byDate = await fetchContributionDays(token, user);
    todayKey = new Date().toISOString().slice(0, 10);
  }

  const stats = computeStats(byDate, todayKey);
  const svg = renderSvg(stats);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, svg);
  console.log(`Streak card written to ${outPath}`);
  console.log(`total=${stats.total} current=${stats.current} longest=${stats.longest}`);
}

main().catch((err) => {
  console.error(`Streak generation failed: ${err.message}`);
  process.exit(1);
});
