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

    public class PKBInterface : IPKBInterface {
        public List<ProgramElement> Init(string path)
        {
            var errCode =  SpaApi.Init(path);
            if (errCode != 0)
            {
                throw new ArgumentException(SpaApi.GetError());
            }
            var result = new List<ProgramElement>();

            uint i = 0;
            while(true)
            {
                var temp = SpaApi.GetNodeMetadata(i);
                
                if(temp.line_no == 0)
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
            throw new NotImplementedException();
        }

        public bool Follow(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            var pointer = SpaApi.Follows(s1_type, s1, s2_type, s2);
            return Marshal.ReadByte(unchecked((IntPtr)(long)(ulong)pointer)) > 0;
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
                throw new InvalidOperationException(SpaApi.GetError());
        }
    }
}