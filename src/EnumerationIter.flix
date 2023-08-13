mod EnumerationIter {
    import java.util.Enumeration;

    pub def toList(e: Enumeration): List[t] \ IO =
        import java.util.Enumeration.hasMoreElements(): Bool \ IO;
        import java.util.Enumeration.nextElement(): t \ IO;
        region r {
            let l = MutList.new(r);
            def loop() =
                match hasMoreElements(e) {
                    case true =>
                        MutList.push!(nextElement(e), l);
                        loop()
                    case false => MutList.toList(l)
                };
            loop()
        }
        

}