using System.Runtime.Serialization;

namespace SPA.PQL.Exceptions
{
    [Serializable]
    internal class NotValidatedException : Exception
    {
        public NotValidatedException()
        {
        }

        public NotValidatedException(string? message) : base(message)
        {
        }

        public NotValidatedException(string? message, Exception? innerException) : base(message, innerException)
        {
        }

        protected NotValidatedException(SerializationInfo info, StreamingContext context) : base(info, context)
        {
        }
    }
}