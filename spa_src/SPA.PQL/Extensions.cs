using System.Text.RegularExpressions;

namespace SPA.PQL {
    public static class Extensions {
        public static string[] SplitAt(this string str, char c)
        {
            int index = str.IndexOf(c);

            if (index < 0)
                return [str];

            if (index == str.Length - 1)
                return [str.Substring(0, index)];

            return [str.Substring(0, index), str.Substring(index + 1)];
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
    }
}