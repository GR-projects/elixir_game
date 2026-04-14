// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/web.ex",
    "../lib/web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        // Dark fantasy RPG palette
        dark: {
          950: "#0a0a0f",
          900: "#0d0d14",
          850: "#11111a",
          800: "#161620",
          700: "#1e1e2e",
          600: "#2a2a3d",
          500: "#3a3a52",
        },
        gold: {
          50:  "#fff9e6",
          100: "#fff0b3",
          200: "#ffe680",
          300: "#ffd94d",
          400: "#ffcc1a",
          500: "#d4a017",
          600: "#b8860b",
          700: "#8b6914",
          800: "#5e4a1e",
          900: "#3d2e0a",
        },
        crimson: {
          50:  "#fff0f0",
          100: "#ffd6d6",
          200: "#ffadad",
          300: "#ff7a7a",
          400: "#ff4747",
          500: "#dc2626",
          600: "#b91c1c",
          700: "#8b1a1a",
          800: "#5c1414",
          900: "#3b0d0d",
        },
        arcane: {
          50:  "#f3f0ff",
          100: "#e0d6ff",
          200: "#c4adff",
          300: "#a37aff",
          400: "#8b5cf6",
          500: "#7c3aed",
          600: "#6d28d9",
          700: "#5b21b6",
          800: "#4c1d95",
          900: "#3b0f7a",
        },
        emerald: {
          400: "#34d399",
          500: "#10b981",
          600: "#059669",
        },
      },
      fontFamily: {
        display: ['"Cinzel"', 'serif'],
        body: ['"Inter"', 'sans-serif'],
        mono: ['"Fira Code"', 'monospace'],
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
      },
      boxShadow: {
        'glow-gold': '0 0 15px rgba(212, 160, 23, 0.3)',
        'glow-gold-lg': '0 0 30px rgba(212, 160, 23, 0.4)',
        'glow-crimson': '0 0 15px rgba(220, 38, 38, 0.3)',
        'glow-arcane': '0 0 15px rgba(124, 58, 237, 0.3)',
        'glow-arcane-lg': '0 0 30px rgba(124, 58, 237, 0.4)',
        'inner-glow': 'inset 0 0 20px rgba(212, 160, 23, 0.1)',
      },
      borderColor: {
        'gold-fade': 'rgba(212, 160, 23, 0.3)',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'shimmer': 'shimmer 2s linear infinite',
        'float': 'float 6s ease-in-out infinite',
      },
      keyframes: {
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-10px)' },
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../../../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
  ]
}
