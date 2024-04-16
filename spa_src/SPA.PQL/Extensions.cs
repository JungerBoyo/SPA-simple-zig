using System.Text.RegularExpressions;

namespace SPA.PQL {
    public static class Extensions {
        public static string[] SplitAt(this string str, string regex)
        {
            var match = Regex.Match(str, regex);

            if (!match.Success)
                return [str];

            if (match.Index == str.Length - 1)
                return [str.Substring(0, match.Index)];

            return [str.Substring(0, match.Index), str.Substring(match.Index + match.Length)];
        }

        public static int IndexOfAny(this string str, IEnumerable<string> searchedPhrases)
        {
            int result = str.Length;
            foreach (var phrase in searchedPhrases)
            {
                var match = Regex.Match(str, phrase);

                if (match.Success && match.Index < result)
                    result = match.Index;
            }

            if (result < str.Length)
                return result;

            return -1;
        }

        public static bool Contains<T>(this T[] array, T value)
        {
            foreach (var item in array)
            {
                if (item is null)
                {
                    if (value is null)
                        return true;

                    continue;
                }

                if (item.Equals(value))
                    return true;
            }

            return false;
        }
    }
}