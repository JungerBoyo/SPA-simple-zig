using System.Runtime.InteropServices;
using SPA.PQL.API;
using SPA.PQL.Elements;

namespace SPA.PQL.Abstractions {
    public interface IPKBInterface {
        List<ProgramElement> Init(string path);
        bool Parent(uint s1_type, uint s1, uint s2_type, uint s2);
        bool Follow(uint s1_type, uint s1, uint s2_type, uint s2);
        bool Uses(uint s1_type, uint s1, uint s2_type, uint s2);
        bool Modifies(uint s1_type, uint s1, uint s2_type, uint s2);
        void DeInit();
    }

    public sealed class PKBInterface : IPKBInterface {
        public List<ProgramElement> Init(string path)
        {
            var errCode =  SpaApi.Init(path);
            if (errCode != 0)
            {
                var pointer = SpaApi.GetErrorMessage();
                throw new ArgumentException(Marshal.PtrToStringAnsi(pointer));
            }
            var result = new List<ProgramElement>();

            uint i = 0;
            while(true)
            {
                var temp = SpaApi.GetNode(i);
                
                if(temp.type == 0)
                    break;
                
                result.Add(new ProgramElement()
                {
                    Type = (SpaApi.StatementType)temp.type,
                    LineNumber = temp.line_no,
                    StatementNumber = temp.statement_id,
                });

                i++;
            }

            return result;
        }

        public bool Parent(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            var pointer = SpaApi.Parent(s1_type, s1, "", s2_type, s2, "");
            
            if (pointer == 0)
                return false;
            
            return Marshal.ReadByte(unchecked((IntPtr)(long)(ulong)pointer)) > 0;
        }

        public bool Follow(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            if (s1_type == s2_type && s1 == s2)
                return false;
            
            var pointer = SpaApi.Follows(s1_type, s1, "", s2_type, s2, "");

            if (pointer == 0)
                return false;
            
            return (uint)Marshal.ReadInt32(unchecked((IntPtr)(long)(ulong)pointer)) > 0;
        }

        public bool Uses(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            throw new NotImplementedException();
        }

        public bool Modifies(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            throw new NotImplementedException();
        }

        public void DeInit()
        {
            var errCode = SpaApi.Deinit();

            if (errCode != 0)
            {
                var pointer = SpaApi.GetErrorMessage();
                var message = Marshal.PtrToStringAnsi(pointer);
                throw new InvalidOperationException(message);
            }
        }
    }
}